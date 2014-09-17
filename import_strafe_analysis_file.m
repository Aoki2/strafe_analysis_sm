function lsData = import_strafe_analysis_file(anFile)

%Call bash script to strip out sourcemod log prefix (timestamp etc)
%(need Cygwin installed and $PATH set if on Windows)
lanSysCall = ['sh .' filesep 'strip_sm_log_prefix.bash ' anFile];
system(lanSysCall);

% Import the file
newData1 = importdata(anFile);

lsData = [];

% Create new variables in the base workspace from those fields.
for i = 1:size(newData1.colheaders, 2)
    lsData.(genvarname(newData1.colheaders{i})) = newData1.data(:,i);
end

