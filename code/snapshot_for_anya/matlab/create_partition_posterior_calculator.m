function calc = create_partition_posterior_calculator(log_expectations,prior,poi)
% Inputs:
%   log_expectations: function handle, maps matrices of additive natural 
%                     parameters to log-expectations
%   prior: Exchangeable prior over partitions, for example CRP. It needs to
%          implement prior.logprob(counts), where counts are the number of 
%          customers per table (partition block sizes).
%   poi: partition of interest, given as an n-vector of table assignments,
%        where there are n customers. The tables are numbered 1 to m. 
    
    if nargin==0
        test_this();
        return;
    end

    n = length(poi);  %number of customers
    
    %Generate flags for all possible (non-empty) subsets
    ns = 2^n-1;       %number of non-empty customer subsets
    subsets = logical(mod(fix(bsxfun(@rdivide,0:ns,2.^(0:n-1)')),2));
    subsets = subsets(:,2:end);  % dump empty subset
    %subsets = sparse(subsets);
    
    %maps partition to flags indicating subsets (blocks)
    % also returns table counts
    function [flags,counts] = labels2weights(labels)
        [blocks,counts] = labels2blocks(labels);
        %blocks = sparse(blocks);
        [tf,loc] = ismember(blocks',subsets','rows');  %seems faster with full matrices
        assert(all(tf));
        flags = false(ns,1);
        flags(loc) = true; 
    end
    
    [poi_weights,counts] = labels2weights(poi);
    log_prior_poi = prior.logprob(counts);
    
    
    %precompute weights and prior for every partition
    Bn = Bell(n);
    PI = create_partition_iterator(n);
    Weights = false(ns,Bn);
    log_prior = zeros(1,Bn);
    for j=1:Bn
        labels = PI.next();
        [Weights(:,j),counts] = labels2weights(labels);
        log_prior(j) = prior.logprob(counts);
    end
    
    Weights = sparse(Weights);
    subsets = sparse(subsets);
    poi_weights = sparse(poi_weights);
    
    calc.logPost = @logPost;
    calc.logPostPoi = @logPostPoi;
    
    
    function y = logPostPoi(A,B)
    % Inputs:
    %   A,B: n-column matrices of natural parameters for n meta-embeddings
    % Output:
    %   y: log P(poi | A,B, prior)
    
        assert(size(B,2)==n && size(A,2)==n);


        %compute subset likelihoods
        log_ex = log_expectations(A*subsets,B*subsets); 

        %compute posterior
        num = log_prior_poi + log_ex*poi_weights;
        dens = log_prior + log_ex*Weights;
        maxden = max(dens);
        den = maxden+log(sum(exp(dens-maxden)));
        y = num - den;
    
    end

    function f = logPost(A,B)
    % Inputs:
    %   A,B: n-column matrices of natural parameters for n meta-embeddings
    % Output:
    %   y: log P(poi | A,B, prior)
    
        assert(size(B,2)==n && size(A,2)==n);


        %compute subset likelihoods
        log_ex = log_expectations(A*subsets,B*subsets); 
        
        llh = log_ex*Weights;
        den = log_prior + llh; 
        maxden = max(den);
        den = maxden+log(sum(exp(den-maxden)));
    
        function y = logpost_this(poi)
            [poi_weights,counts] = labels2weights(poi);
            log_prior_poi = prior.logprob(counts);
            num = log_prior_poi + log_ex*poi_weights;
            y = num - den;
        end
        
        f = @logpost_this;
        
    end



end

function test_this

    
    Mu = [-1 0 -1.1; 0 -3 0];
    C = [3 1 3; 1 1 1];
    A = Mu./C;
    B = zeros(4,3);
    B(1,:) = 1./C(1,:);
    B(4,:) = 1./C(2,:);
    scale = 3;
    B = B * scale;
    C = C / scale;
    
    
    close all;
    figure;hold;
    plotGaussian(Mu(:,1),diag(C(:,1)),'blue','b');
    plotGaussian(Mu(:,2),diag(C(:,2)),'red','r');
    plotGaussian(Mu(:,3),diag(C(:,3)),'green','g');
    axis('square');
    axis('equal');

    
    poi = [1 1 2];
    %prior = create_PYCRP(0,[],2,3);
    %prior = create_PYCRP([],0,2,3);
    
    create_flat_partition_prior(length(poi));
    
    calc = create_partition_posterior_calculator(prior,poi);
    f = calc.logPost(A,B);
    exp([f([1 1 2]), f([1 1 1]), f([1 2 3]), f([1 2 2]), f([1 2 1])])
    
    
end


