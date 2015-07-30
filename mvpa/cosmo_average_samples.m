function ds_avg=cosmo_average_samples(ds, varargin)
% average subsets of samples by unique combinations of chunks and targets
%
% ds_avg=cosmo_averaging_measure(ds, 'ratio', ratio, ['nrep',nrep])
%
% Inputs:
%   ds              dataset struct with field:
%     .samples      NS x NF
%     .sa           with fields .targets and .chunks
%   'ratio', ratio  ratio (between 0 and 1) of samples to select for
%                   each average. Not compatible with 'count' (default: 1).
%   'count', c      number of samples to select for each average.
%                   Not compatible with 'ratio'.
%   'resamplings',s Maximum number of times each sample in ds is used for
%                   averaging. Not compatible with 'repeats' (default: 1)
%   'repeats', r    Number of times an average is computed for each unique
%                   combination of targets and chunks. Not compatible with
%                   'resamplings'
%   'seed', d       Use seed d for pseudo-random sampling (optional). If
%                   this option is omitted, then different calls to this
%                   function may (usually: will) return different results.
%
%
% Returns
%   ds_avg          dataset struct with field:
%      .samples     ('nrep'*ntargets*nchunks) x NF, where
%                   ntargets and nchunks are the number of unique targets
%                   and chunks, respectively. Each sample is an average
%                   from samples that share the same values for
%                   .sa.{chunks,targets}. The number of times each sample
%                   is used to compute average values differs by one at
%                   most.
%      .sa          Based on averaged samples.
%      .fa,.a       Same as in ds (if present).
%
% Examples:
%     % generate simple dataset with 3 times (2 targets x 3 chunks)
%     ds=cosmo_synthetic_dataset('nreps',3);
%     size(ds.samples)
%     > [ 18 6 ]
%     cosmo_disp([ds.sa.targets ds.sa.chunks])
%     > [ 1         1
%     >   2         1
%     >   1         2
%     >   :         :
%     >   2         2
%     >   1         3
%     >   2         3 ]@18x2
%     % average each unique combiniation of chunks and targets
%     ds_avg=cosmo_average_samples(ds);
%     cosmo_disp([ds_avg.sa.targets ds_avg.sa.chunks]);
%     > [ 1         1
%     >   1         2
%     >   1         3
%     >   2         1
%     >   2         2
%     >   2         3 ]
%     %
%     % for each unique target-chunk combination, select 50% of the samples
%     % randomly and average these; repeat the random selection process 4
%     % times. Each sample in 'ds' is used twice (=.5*4) as an element
%     % to compute an average. The output has 24 samples
%     ds_avg2=cosmo_average_samples(ds,'ratio',.5,'repeats',4);
%     cosmo_disp([ds_avg2.sa.targets ds_avg2.sa.chunks]);
%     > [ 1         1
%     >   1         2
%     >   1         3
%     >   :         :
%     >   2         1
%     >   2         2
%     >   2         3 ]@24x2
%
% Notes:
%  - this function averages feature-wise; the output has the same features
%    as the input.
%  - it can be used to average data from trials safely without circular
%    analysis issues.
%  - as a result the number of trials in each chunk and target is
%    identical, so balancing of partitions is not necessary for data from
%    this function.
%
% See also: cosmo_balance_partitions
%
% NNO Jan 2014

    % deal with input parameters

    defaults.seed=[];

    opt=cosmo_structjoin(defaults, varargin);
    split_idxs=get_split_indices(ds);

    nsplits=numel(split_idxs);
    bin_counts=cellfun(@numel,split_idxs);

    [split_sample_ids,nrepeat]=get_split_sample_ids(bin_counts,opt);

    nfeatures=size(ds.samples,2);

    mu=zeros(nrepeat*nsplits,nfeatures);
    slice_ids=zeros(nrepeat*nsplits,1);

    row=0;
    for k=1:nsplits
        split_idx=split_idxs{k};
        split_ids=split_sample_ids{k};

        for j=1:nrepeat
            sample_ids=split_idx(split_ids(:,j));

            row=row+1;
            mu(row,:)=mean(ds.samples(sample_ids,:),1);
            slice_ids(row)=sample_ids(1);
        end
    end

    ds_avg=cosmo_slice(ds,slice_ids);
    ds_avg.samples=mu;


function split_idxs=get_split_indices(ds)
    if ~(isstruct(ds) && ...
                isfield(ds,'samples') && ...
                isfield(ds,'sa') && ...
                isfield(ds.sa,'targets') && ...
                isfield(ds.sa,'chunks'))
        error(['First input must be dataset struct with fields '...
                '.samples, .sa.targets and .sa.chunks']);
    end

    split_idxs=cosmo_index_unique({ds.sa.targets,ds.sa.chunks});



function [idx, value]=get_mutually_exclusive_param(opt, names, ...
                                        default_idx, default_value)
    idx=[];
    value=[];

    n=numel(names);

    for k=1:n
        key=names{k};
        if isfield(opt,key)
            value=opt.(key);
            if ~isempty(value)
                if isempty(idx)
                    idx=k;
                else
                    error(['The options ''%s'' and ''%s'' are mutually '...
                            'exclusive '], key, names{idx});
                end
            end
        end
    end

    if isempty(idx)
        idx=default_idx;
        value=default_value;
    end


function [nselect,nrepeat]=get_selection_params(bin_counts,opt)
    [idx,value]=get_mutually_exclusive_param(opt,{'ratio','count'},1,1);

    switch idx
        case 1
            % ratio
            nselect=round(value*min(bin_counts));
        case 2
            % count
            nselect=value;

    end

    ensure_in_range('Number of elements to select',nselect,...
                                            1,min(bin_counts));


    repeat_labels={'resamplings','repeats'};
    [idx2,value2]=get_mutually_exclusive_param(opt,repeat_labels,1,1);
    switch idx2
        case 1
            nrepeat=floor(value2*min(bin_counts./nselect));
        case 2
            nrepeat=value2;
    end

    ensure_in_range(sprintf('Value for ''%s''',repeat_labels{idx2}),...
                            nrepeat,1,Inf);

function ensure_in_range(label, val, min_val, max_val)
    postfix=[];
    while true
        if ~isscalar(val) || ~isnumeric(val)
            postfix='must be numeric scalar';
            break;
        end

        if round(val)~=val
            postfix='must be an integer';
        end

        if val<min_val
            postfix=sprintf('cannot be less than %d', min_val);
            break;
        end

        if val<min_val
            postfix=sprintf('cannot be greater than %d', max_val);
            break;
        end

        break;
    end

    if ~isempty(postfix)
        msg=[label postfix];
        error(msg);
    end


function [sample_ids,nrepeat]=get_split_sample_ids(bin_counts,opt)
    [nselect,nrepeat]=get_selection_params(bin_counts,opt);

    % number of saples for each unique chunks-targets combination
    nsplits=numel(bin_counts);

    % allocate space for output
    sample_ids=cell(nsplits,1);

    % select samples randomly, but in a manner so that each one is used
    % approximately equally often
    for k=1:nsplits
        bin_count=bin_counts(k);
        sample_ids{k}=cosmo_sample_unique(nselect,bin_count,nrepeat,opt);
    end

