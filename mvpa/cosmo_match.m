function msk=cosmo_match(haystack, needle, varargin)
% returns a mask indicating matching occurences in two arrays or cells
% relative to the second array
%
% msk=cosmo_match(haystack1, needle1[, needle2, haystack2, ...])
%
% Inputs:
%   haystack*         numeric vector, or cell with strings. A string is
%                     also allowed and interpreted as the name of a feature
%                     dimension ('i','j' or 'k' in fmri datasets; 'chan',
%                     'time', or 'freq' in MEEG datasets), and its 
%                     respective values (from ds.a.dim.values{dim}, where
%                     dim is the dimension corresponding to haystack) as
%                     indexed by ds.fa.(haystack) are used as haystack.
%   needle*           numeric vector, or cell with strings. A string is
%                     also allowed and interpreted as {needle}.
%   
% Output:
%   msk               boolean array of the same size as haystack, with
%                     true where the value in haystack is equal to at least
%                     one value in needle. If multiple needle/haystack
%                     pairs are provided, then the haystack inputs should 
%                     have the same number of elements, and msk contains 
%                     the intersection of the individual masks. 
%                     
% Examples
%   - % simple character comparison
%     cosmo_match({'a','b','c'},{'b','c','d','e','b'})
%     > [false true true]
%   - % swap the order of inputs
%     cosmo_match({'b','c','d','e','b'},{'a','b','c'})
%     > [true true false false true]
%
%   - % in an fMRI dataset, get mask for features with with first spatial
%     % dimension indices 5 or 7.
%     msk=cosmo_match(ds.fa.i,[5 7]);
%
%   - % get mask for chunk values 1 and 4
%     msk=cosmo_match(ds.sa.chunks,[1 4]);
%
%   - % get mask for chunk values 1 and 4, and target values 1, 3 or 6.
%     msk=cosmo_match(ds.sa.chunks, [1 4], ds.sa.targets, [1 3 6]);
%
%   - % get feature mask for the fourth channel in an MEEG dataset
%     msk=cosmo_match(ds.fa.chan,4)
%
% Notes:
%   - the output of this function can be used with cosmo_slice
%     to select features or samples of interest
%   - to select feature dimension values in an fmri or meeg dataset 
%     (e.g., channel selection), see cosmo_feature_dim_match
%
% See also: cosmo_slice, cosmo_stack, cosmo_feature_dim_match
%
% NNO Sep 2013


    if nargin<2
        error('Need at least two input arguments')
    elseif mod(nargin,2) ~= 0
        error('Need an even number of input arguments');
    end
    
    if ischar(needle)
        needle={needle};
    end

    if isnumeric(haystack) && isnumeric(needle) && numel(needle)==1
        % optimization for most standard case: vector and scalar
        check_vec(haystack);
        msk=needle==haystack;
    elseif isa(needle,'function_handle')
        if iscell(haystack)
            msk=cellfun(needle,haystack,'UniformOutput',true);
        else
            msk=needle(haystack);
        end
    else
        nrows=check_vec(needle);
        ncols=check_vec(haystack);
        
        if isnumeric(needle) && isnumeric(haystack)
            matches=bsxfun(@eq, needle(:), haystack(:)');
        elseif iscell(needle) && iscell(haystack)
            matches=false(nrows,ncols);
            
            for k=1:ncols
                if ~ischar(haystack{k})
                    error('cell must contain strings');
                end
            end
            
            for k=1:nrows
                needlek=needle{k};
                if ~ischar(needlek)
                    error('cell must contain strings');
                end
                match_indices=strcmp(needlek,haystack);
                matches(k, match_indices)=true;
            end
        else
            error(['Illegal inputs %s and %s: need numeric arrays or '...
                    'cell with strings'],class(needle),class(haystack));
        end
        
        msk=reshape(sum(matches,1)>0,size(haystack));
    end

    if nargin>2
        me=str2func(mfilename()); % immune to renaming
        other_msk=me(varargin{:});  % use recursion

        % check the size is the same
        if numel(msk) ~= numel(other_msk)
            error('Cannot make conjunction: masks have %d ~= %d elements',...
                    numel(msk), numel(other_msk));
        end

        % conjunction
        msk=msk & other_msk;
    end

function c=just_convert_str2cell(x)
    % only if x is a string, it is converted to char. otherwise x is returned
    if ischar(x)
        c={x};
    else
        c=x;
    end

function n=check_vec(x)
    % checks whether it's a vector, and if so, returns the number of elements
    sz=size(x);
    if numel(sz) ~= 2 || sum(sz>1)>1
        error('Input argument is not a vector');
    end
    n=numel(x);
        