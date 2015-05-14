clear;close all

file = 'R1032_2012-07-06_15.12/R1032_2012-07-06_15.12.plg';

% Hello silly sam 

CurrentHeightStr = 'Builds.State.CurrentBuild.CurrentHeight';
TaskStr = 'Process.ProcessManager.Task';

NumberOfHeightBins  = 15;

FID = fopen(file);%

C = textscan(FID,' %s %s %s %s %s','delimiter', '|','CommentStyle', '#' );

fclose(FID);  %This closes the file

TimeStamp = datenum(C{1},'yyyy-mm-dd HH:MM:SS.FFF'); %converts the timestamp string to a number to work with number is number of days since (January 1, 0000)

%%
Height = str2double(C{5}(strcmp(CurrentHeightStr,C{2})));
LayerStartTime = TimeStamp(strcmp(CurrentHeightStr,C{2}));

Task = C{5}(strcmp(TaskStr,C{2}));
TaskStartTime = TimeStamp(strcmp(TaskStr,C{2}));

%% Rename task with no name
Task(strcmp('', Task)) = cellstr('No name given'); %Replaces any of the Tasks with no name by the string 


DurationInDays = diff(TaskStartTime);  %Calculates the duration each of task in days by finding difference between [X(i+1)-X(i) .. etc etc

%% Basic Infomation extraction

MaxHeight = Height(end);  %finds the height at the end of the build
TotalTasks = size(Task,1);  %Counts total number of tasks analysed

BuildBegunD = TaskStartTime(1);
BuildEndD = TaskStartTime(end);

TotalBuildTimeD = BuildEndD-BuildBegunD; %Calculates number of days to Finish the build

Task(length(Task)) = []; %Removes the last task, process stopped.
TotalTasks = TotalTasks - 1; %Removes one from the number of tasks since we are not counting stoped as a task

UniqueTasks = unique(Task); %Finds all the tasks done during this builds
NumUTasks = size(UniqueTasks,1);  %the number of unique tasks carried out

%% Sorting all Tasks and durations

Match = zeros(TotalTasks,NumUTasks);  %Preallocate a matrix for speed
TaskDurationSorted = Match;  %Matrix to speed program

for ii = 1:NumUTasks   %this loop creates a matrix where each row has one non zero entry: column matches the unique task whereas row equates to start time
    Match(:,ii) = strcmp(Task,UniqueTasks(ii));  %Logical check gives 1 if tasks match or 0 if not
    TaskDurationSorted(:,ii) = Match(:,ii) .*  DurationInDays;  %Times logical check by duration to get durations for each task
end

TotalTaskOccurences = sum(Match);   %gives a row vector with each entry corisonding to the number of times that task was done
TotalTaskDuration = sum(TaskDurationSorted);%gives a row vector with each entry corisonding to the Total times spent on each task
AverageTaskTime = TotalTaskDuration ./ TotalTaskOccurences;

TaskTimeC = cellstr(datestr(AverageTaskTime,'HH:MM:SS.FFF'));   %Converts from the purely numeric number of days to standrad time date format
AverageTaskTimeC = cellstr(datestr(AverageTaskTime,'HH:MM:SS.FFF'));  %Also converst from strings to a cell array (like a vector) to allow to be added


%% Height Bining for all tasks

HeightBinSize = MaxHeight/NumberOfHeightBins;
HeightThreshold = HeightBinSize:HeightBinSize:MaxHeight;%The threshold time below which tasks are counted as part of this binn

HeightTimeThres = zeros(1,NumberOfHeightBins);
CumTaskOcurencesH = zeros(NumberOfHeightBins,NumUTasks);
CumTotalTaskTimeDH = zeros(NumberOfHeightBins,NumUTasks);


for ii = 1:NumberOfHeightBins
    HeightTimeThres(ii) = LayerStartTime(find(Height<=HeightThreshold(ii), 1, 'last' ));
    PerBinH = find(TaskStartTime < HeightTimeThres(ii));  %Finds the number of tasks done at a time below the threshold
    BinnedOccurencesH = Match(PerBinH,:);  %Gets the number of occurences in each bin
    BinnedTaskDurationH = TaskDurationSorted(PerBinH,:); %Gets the times of all the occurences of the tasks
    for jj = 1:NumUTasks
        CumTaskOcurencesH(ii,jj) = nnz(BinnedOccurencesH(:,jj));%Counts the non zero elements of this column in match
        CumTotalTaskTimeDH(ii,jj) = sum(BinnedTaskDurationH(:,jj));   %Finds the total time for each task
    end
end

HeightBinsTask = [CumTotalTaskTimeDH(1,:);diff(CumTotalTaskTimeDH)];  %finds the total time for each task per bin

TableOutput = cell(NumberOfHeightBins, NumUTasks);

for ii = 1:NumUTasks
    TableOutput(:,ii) = cellstr(datestr(HeightBinsTask(:,ii),'HH:MM:SS.FFF'));
end

OcurencesBinsTaskH = [CumTaskOcurencesH(1,:);diff(CumTaskOcurencesH)];  %Number of occurences per bin


%% Display table of results

figure('Name','Total and Average Time for each Task of the entire build')
uitable('Units','normalized','Position',[0 0 1 1],...
    'Data',[UniqueTasks TaskTimeC num2cell(TotalTaskOccurences') AverageTaskTimeC],...
    'ColumnName',{'Task','Total Time','Occurences' ,'Average Time'},...
    'ColumnWidth',{300 'auto' 'auto' 'auto'}); 

%% This section creats a random colour map, useful if displaying lots/all the tasks 
colourmap = jet ;

randnum = randperm(size(colourmap,1)) ;
Random=zeros(64,3);

for k = 1 : length(randnum)
    
    Random(k,:) = colourmap(randnum(k),:) ;
    
end

%% Include only wanted tasks on graph

UniqueTasks = unique(Task); %Finds all the tasks done during this builds
Include = listdlg('PromptString','All tasks in this build shown below. Highlight Tasks to include on graph',...
                'SelectionMode','multiple', 'ListString',UniqueTasks,...
                'Name','Select Tasks','ListSize',[400 350]);
            
IncludedTasks = UniqueTasks(Include); %Creates list of names of included tasks

IncludedTasksGraph = HeightBinsTask(:,Include);  %seperates only the information about the tasks you wish to display on the graph

figure('Name','Time for each task in Height Bins')
bar(HeightThreshold , IncludedTasksGraph * 24 , 'stacked')
shading faceted    %adds lines between the different tasks stacked on top of each other
colormap(jet)  %Change the colour here using standard matlab colour maps or the random one defined above
xlabel('Height (mm)','FontWeight','bold')
ylabel('Time per Task (hours)','FontWeight','bold')
legend(IncludedTasks,'Location','EastOutside')
grid on
box on
