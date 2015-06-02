clear;close all
%% Decide what to analyse

[FileNameZ,PathName,FilterIndex] = uigetfile('*.zip'); %user selects zip file
FileName = FileNameZ(1:end-4);  %remove last four characters '.zip'


PosAnalyse  = {'Time per task per layer','Baseplate temperature vs height','Temperatures'}; %list of possible tasks

Analyse = listdlg('PromptString','Select analysis',...
                'SelectionMode','multiple', 'ListString',PosAnalyse,...
                'Name','Select Tasks','ListSize',[400 350]);

%%
cd(PathName); InFolder = dir;  % change directory to that selected and list the contensts fo teh directory

DirectoriesInFolder = InFolder([InFolder.isdir]); % list of folders only in directory

Folder = 0;
for ii = 1:length(DirectoriesInFolder)
    if  strcmp(DirectoriesInFolder(ii).name,FileName) % find if unzipped version exists already
        Folder = ii;
    end
end

if Folder>0
    cd(DirectoriesInFolder(Folder).name)
else
    mkdir(FileName); unzip(FileNameZ,FileName);  cd(FileName) %make new directory with name of file and unzip to there
end

%%

FID = fopen([FileName '.plg']);%

C = textscan(FID,' %s %s %s %s %s','delimiter', '|','CommentStyle', '#' );

fclose(FID);  %This closes the file

TimeStamp = datenum(C{1},'yyyy-mm-dd HH:MM:SS.FFF'); %converts the timestamp string to a number to work with number is number of days since (January 1, 0000)

%%

LayerHeightIdx = strcmp('Builds.State.CurrentBuild.CurrentHeight',C{2});

Height = str2double(C{5}(LayerHeightIdx));
LayerStartTime = TimeStamp(LayerHeightIdx);

TaskIdx = strcmp('Process.ProcessManager.Task',C{2});

Task = C{5}(TaskIdx);
TaskStartTime = TimeStamp(TaskIdx);

%% Analyse theme time with height

if any(Analyse==1)
    
    Task(strcmp('', Task)) = cellstr('No name given'); %Replaces any of the Tasks with no name by the string
    
           
    TotalTasks = sum(TaskIdx);  %Counts total number of tasks analysed
    
    TotalBuildTimeD = TaskStartTime(end)-TaskStartTime(1); %Calculates number of days to Finish the build
    
    Task(end) = []; %Removes the last task, process stopped.
    TotalTasks = TotalTasks - 1; %Removes one from the number of tasks since we are not counting stoped as a task
    
    UniqueTasks = unique(Task); %Finds all the tasks done during this builds
    NumUTasks = size(UniqueTasks,1);  %the number of unique tasks carried out
    
    % Sorting all Tasks and durations
    
    Match = zeros(TotalTasks,NumUTasks);  %Preallocate a matrix for speed
    TaskDurationSorted = Match;  %Matrix to speed program
    
    for ii = 1:NumUTasks   %this loop creates a matrix where each row has one non zero entry: column matches the unique task whereas row equates to start time
        Match(:,ii) = strcmp(Task,UniqueTasks(ii));  %Logical check gives 1 if tasks match or 0 if not
        TaskDurationSorted(:,ii) = Match(:,ii) .*  diff(TaskStartTime);  %Times logical check by duration to get durations for each task
    end
    
    TotalTaskOccurences = sum(Match);   %gives a row vector with each entry corisonding to the number of times that task was done
    TotalTaskDuration = sum(TaskDurationSorted);%gives a row vector with each entry corisonding to the Total times spent on each task
    AverageTaskTime = TotalTaskDuration ./ TotalTaskOccurences;
    
    
    
    % Height Bining for all tasks
    NumberOfLayers  = length(Height);
    
    CumTotalTaskTimeDH = zeros(NumberOfLayers,NumUTasks);
    
    
    for ii = 1:NumberOfLayers
        PerBinH = find(TaskStartTime < LayerStartTime(ii));  %Finds the number of tasks done at a time below the threshold
        BinnedOccurencesH = Match(PerBinH,:);  %Gets the number of occurences in each bin
        BinnedTaskDurationH = TaskDurationSorted(PerBinH,:); %Gets the times of all the occurences of the tasks
        for jj = 1:NumUTasks
            CumTotalTaskTimeDH(ii,jj) = sum(BinnedTaskDurationH(:,jj));   %Finds the total time for each task
        end
    end
    
    HeightBinsTask = [CumTotalTaskTimeDH(1,:);diff(CumTotalTaskTimeDH)];  %finds the total time for each task per bin
    
    TableOutput = cell(NumberOfLayers, NumUTasks);
    
    for ii = 1:NumUTasks
        TableOutput(:,ii) = cellstr(datestr(HeightBinsTask(:,ii),'HH:MM:SS.FFF'));
    end
    
    
    %%
    % Display table of results
    
    figure('Name','Total and Average Time for each Task of the entire build')
    uitable('Units','normalized','Position',[0 0 1 1],...
        'Data',[UniqueTasks cellstr(datestr(TotalTaskDuration,'HH:MM:SS.FFF'))...
        num2cell(TotalTaskOccurences') ...
        cellstr(datestr(AverageTaskTime,'HH:MM:SS.FFF')); ...
        {'Total' datestr(sum(TotalTaskDuration),'dd HH:MM:SS.FFF') sum(TotalTaskOccurences) ''}],...
        'ColumnName',{'Task','Total Time','Occurences' ,'Average Time'},...
        'ColumnWidth',{300 'auto' 'auto' 'auto'});
    
    % Include only wanted tasks on graph
    %%
    Include = listdlg('PromptString','All tasks in this build shown below. Highlight Tasks to include on graph',...
        'SelectionMode','multiple', 'ListString',UniqueTasks,...
        'Name','Select Tasks','ListSize',[400 350],'InitialValue',[7 10:12 14:length(UniqueTasks)]);
            
    figure('Name','Time for each task in height bins')
    plot(Height , HeightBinsTask(:,Include) * 24*60*60,'linewidth',0.01)%,'LineStyle','none')
    hold on
%     plot(Height , sum(HeightBinsTask(:,Include),2) * 24*60*60)
    colormap(jet)  
    xlabel('Height (mm)')
    ylabel('Time per task (s)')
    legend(UniqueTasks(Include),'Location','EastOutside')
    grid on
    box on

end

if any(Analyse==2)
    %% Analyse temperature change
    %% Analyse temperature change
    TempIdx = strcmp('OPC.Temperature.BottomTemperature',C{2});
        TempIdx2 = strcmp('OPC.Temperature.ExtraTemp2',C{2});

    BasePlateTemperatures = str2double(C{5}(TempIdx));
    ExtraTemperatures = str2double(C{5}(TempIdx2));
   
    BaseTempTime = TimeStamp(TempIdx);
    ExtraTemperaturesTime = TimeStamp(TempIdx2);
    figure
    axes('outerposition',[0 0.5 1 0.5])
    plot((BaseTempTime-TaskStartTime(1))*24,BasePlateTemperatures)
    hold on
    plot((ExtraTemperaturesTime-TaskStartTime(1))*24,ExtraTemperatures,'r')

    xlabel('Time (hours)')
    ylabel(sprintf('Baseplate temperature (%cC)', char(176)))

    [~,k] = histc(BaseTempTime,[LayerStartTime; inf]);
    [~,k2] = histc(ExtraTemperaturesTime,[LayerStartTime; inf]);
    
    axes('outerposition',[0 0 1 0.5])
    plot(Height(k),BasePlateTemperatures)
    hold on
    plot(Height(k2),ExtraTemperatures)

    ylabel(sprintf('Baseplate temperature (%cC)', char(176)))
    xlabel('Build height (mm)')
    
    TTextFileID = fopen('Temperatures.txt','w');
    
    TemperatureTable = table(datestr(BaseTempTime,'yyyy-mm-dd HH:MM:SS.FFF'),Height(k),BasePlateTemperatures);
    TemperatureTable.Properties.VariableNames =  {'Time','Height','Temperature'};
    
    writetable(TemperatureTable,'Temperatures.txt','Delimiter','\t')
    
    fclose(TTextFileID);

end

if any(Analyse==3)
    %% Analayse Temperatures with 3 thermocuples for preheat tests
  
    TempIdx = strcmp('OPC.Temperature.BottomTemperature',C{2});
        TempIdx1 = strcmp('OPC.Temperature.ExtraTemp1',C{2});
        TempIdx2 = strcmp('OPC.Temperature.ExtraTemp2',C{2});

    BasePlateTemperatures = str2double(C{5}(TempIdx));
    ExtraTemperature1 = str2double(C{5}(TempIdx1));
    ExtraTemperature2 = str2double(C{5}(TempIdx2));
    
    BaseTempTime = TimeStamp(TempIdx);
    ExtraTemperaturesTime1 = TimeStamp(TempIdx1);
    ExtraTemperaturesTime2 = TimeStamp(TempIdx2);
    
    
    figure
    plot((BaseTempTime-TaskStartTime(1))*24,BasePlateTemperatures)
    hold on
    plot((ExtraTemperaturesTime1-TaskStartTime(1))*24,ExtraTemperature1,'r')
    hold on
    plot((ExtraTemperaturesTime2-TaskStartTime(1))*24,ExtraTemperature2,'g')
    
    legend('Bottom temperature','Thermocouple 1','Thermocouple 2')

    xlabel('Time (hours)')
    ylabel(sprintf('Temperature (%cC)', char(176)))
end


% TempChange = zeros(NumberOfLayers,4);
% for ii = 1:NumberOfLayers
%     
%     Temp = BasePlateTemperatures(k==ii);
%     
%     TempChange(ii,1) = mean(Temp);
%     TempChange(ii,2) = std(Temp);
%     TempChange(ii,3) = max(Temp)-TempChange(ii,1);
%     TempChange(ii,4) = min(Temp)-TempChange(ii,1);
%     
% end



