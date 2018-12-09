function rv = ExtractBibTeXEntries(bbl_fns, bib_fns, out_fn)
% function rv = ExtractBibTeXEntries(bbl_fns, bib_fns, out_fn)
% Extracts only the used entries from BibTeX .bib file(s)
% Input: 
%     bbl_fns: Either a string or a cell array of strings
%         The file name(s) of the .bbl files which contain the bibliography tags 
%         in the \bibitem commands
%     bib_fns: Either a string or a cell array of strings
%         The file name(s) of the .bib files from which the actually used entries
%         shall be extracted
%     out_fn: The output .bib file name which will contain only those entries from 
%         all .bib files whose tags appear in the bbl file(s). MAy be empty
%         string, then nothing is written, just the content returned
% Output:
%     rv: The content of the output bib file as a single string.
% Action: Reads all bbl_fns and bib_fns. A warnings is issued when there are duplicate 
%     entries in the bib file(s), and another warning for each duplicate entry where the 
%     actual entries are not identical.
%     Writes the content to out_fn
%     
% Julius Muschaweck, 2018
% Provided to the public domain under the UnLicense (

    if iscell(bbl_fns)
        tags = {};
        for i = 1:length(bbl_fns)
            tags = cat(2,tags,GetBBL(bbl_fns{i}));
        end
    else
        tags = GetBBL(bbl_fns);
    end
    sortedtags = sort(tags);
    uniquetags = unique(sortedtags);
    
    if iscell(bib_fns)
        bibentries = GetBib(bib_fns{1});
        for i = 2:length(bib_fns)
            bibentries = cat(2,bibentries,GetBib(bib_fns{i}));
        end
    else
        bibentries = GetBib(bib_fns);
    end
    ne = length(bibentries);    
    entrytags = cell(ne,1);
    bibentries2= cell(ne,1);
    for i = 1:ne
        entrytags{i} = bibentries(i).tag;
        bibentries2{i} = bibentries(i).entry;
    end
    [sortedentrytags,I] = sort(entrytags);
    sortedbibentries = bibentries(I);
    duplicates = false;
    nonidentical = false;
    for i = 1:(ne-1)
        if strcmp(sortedentrytags{i},sortedentrytags{i+1})
            duplicates = true;
            if ~(strcmp(sortedbibentries(i).entry,sortedbibentries(i+1).entry))
                nonidentical = true;
                warning('nonidentical entries for tag %s',sortedentrytags{i});
            end
        end
    end
    if duplicates && ~nonidentical
        warning('duplicate entries, but identical content');
    end
    bibentriesmap = containers.Map(entrytags,bibentries2);
    
    output = '';
    ntags = length(uniquetags);
    for i = 1:ntags
        if i > 1
            output = sprintf('%s\n',output);
        end
        itag = uniquetags{i};
        if bibentriesmap.isKey(itag)
            ientry = bibentriesmap(itag);
            output = [output ientry];
        else
            warning('no entry for key %s',itag);
        end
    end
    rv = output;
    if ischar(out_fn) && length(out_fn) > 0
        fh = fopen(out_fn,'w');
        fwrite(fh, output);
    end
end

function rv = GetBBL(bbl_fn)
% \begin{thebibliography}{10}
% 
% \bibitem{gamma_design_1995}
% Design patterns: elements of reusable object-oriented software.
fh = fopen(bbl_fn);
txt = fread(fh,'*char');
txt2 = txt';
pattern = '\\bibitem{\w*}';
idx = regexp(txt2,pattern,'match');
for i = 1:length(idx)
    tmp = idx{i};
    tmp = tmp(10:(end-1));
    idx{i} = tmp;
end
rv = idx;
end

function rv = GetBib(bib_fn)
fh = fopen(bib_fn);
txt = fread(fh,'*char');
txt2 = txt';
rv = {};
%
%content = ({comment} entry)*
%comment = anything before the first '@' or between the closing } and the
%next @
%entry = '@' entrytype '{' tag ',' nestedStuff '}';
ibib = 1;
imax = length(txt2);
eof = false;
rv = struct('tag','','entry','');
SkipComment();
ientry = 0;
while ~eof
    [entry,tag] = GetEntry();
    tmp.tag = tag;
    tmp.entry = entry;
    ientry = ientry + 1;
    rv(ientry) = tmp;
    SkipComment();
end


    function SkipComment()
        while ~eof && txt2(ibib) ~= '@'
            Advance();
        end
    end

    function [entry,tag] = GetEntry()
        assert(txt2(ibib) == '@','GetEntry: no @');
        istart = ibib;
        AdvanceTo('{');
        level = 1;
        itag1= ibib+1;
        AdvanceTo(',');
        itag2 = ibib-1;
        tag = txt2(itag1:itag2);
        while level > 0
            left = Next('{');
            right = Next('}');
            if left < right
                level = level + 1;
                ibib = left+1;
            else 
                level = level - 1;
                ibib = right+1;
            end
        end
        if ibib >= imax
            eof = true;
        end
        entry = txt2(istart:ibib-1);
    end
    function rv = AdvanceTo( c )
        istart = ibib;
        while ~eof && txt2(ibib) ~= c
            Advance();
        end
        if eof 
            error('AdvanceTo error at position %i, looking for %s',istart,c);
        end
        rv = txt2(istart:ibib);
    end
    function rv = Next(c)
        ii = ibib;
        rv = 1e300;
        while ii <= imax 
            if txt2(ii) == c
                rv = ii;
                break;
            end
            ii = ii + 1;
        end
    end
    function Advance()
        if ibib < imax
            ibib = ibib+1;
        else
            eof = true;
        end
    end
    function rv = Peek()
        assert(ibib < imax,'Peek: eof');
        rv = txt2(ibib+1);
    end
end % GetBib

