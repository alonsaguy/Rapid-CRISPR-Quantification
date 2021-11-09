clear all;
% close all;
%% Clear all;

show_plots = false;
intensity_minimum = 100;

% Set Directory

% test directory = Main_directory = 'C:\Users\lucie\Data\ImageStream_Daniel\20210708 - Pickel Code\';
Main_directory = 'C:\Users\WeissLab\Data\Flow-based imaging\ImageData\20211021\';
% Main_directory = 'C:\Users\lucie\Data\ImageStream_FigureData\Figure3\20210505_Donor2_timecourse\';
cd(Main_directory);
avg_filename_output_xlsx = [Main_directory(end-8:end-1), '_aggregated_data.xlsx'];


% Prepare emtpy table
TABLE_for_excel_summary = table();

% Files required
% Each file must have a .pkl
pkl_variable_names = {'Offset_yx', 'Localization_positions', 'Localization_intensities', 'Number_of_localizations','Localization_confidences','Sum_of_localization_intensity','Sum_of_thresholded_localization_intensity'};
% Each file must have a .txt
warning off all;
% Python environment
pe = pyenv;

% Start with all the PKL files
pkl_files = dir([Main_directory, '**\*.tif.pkl']);

for pkl_file_number = 1:numel(pkl_files)
    pkl_filename = pkl_files(pkl_file_number).name;
    text_filename = strrep(pkl_filename,'_all_ch1.tif.pkl','.txt');
    image_filename = strrep(pkl_filename,'_all_ch1.tif.pkl','_all_ch1.tif');
    small_filename = strrep(pkl_filename,'_all_ch1.tif.pkl','');
    
    filename_output_mat =  [small_filename, '_localized.mat'];
    filename_output_xlsx = [small_filename,'_localized.xlsx'];
    filename_output_xlsx_good_only = [small_filename,'_localized_good_only.xlsx'];
    filename_output_xlsx_good_candidates = [small_filename,'_localized_image_candidates.xlsx'];
    
    % Read txt file
    AMNIS_text_table = readtable(char(strcat(Main_directory, '\', text_filename)));
    Appropriate_size = AMNIS_text_table.Area_M06>175;
    Appropriate_Mean_WL_Value = AMNIS_text_table.MeanPixel_M06_Ch06>-20;
    Appropriate_infocus = AMNIS_text_table.GradientRMS_M06_Ch06>50;
    Appropriate_symmetry = AMNIS_text_table.AspectRatio_M06>=0.85;

    GOOD_cell_calculation = Appropriate_size & Appropriate_Mean_WL_Value & Appropriate_infocus & Appropriate_symmetry;
    
    % Read pkl file
    fid=py.open([Main_directory, '\', pkl_filename],'rb');
    loaded_dict=py.pickle.load(fid);
    triggered = false;
    PKL_cell = {};
    n = 0; % This reads over every cell entry in the pkl file.
    while triggered == false
        try
            temp_pkl_variable = ConvertPythonList2cell(loaded_dict{n},intensity_minimum);
            PKL_cell = [PKL_cell;temp_pkl_variable];
        catch
            triggered = true; % This means there are no more variables.
            continue
        end
        n = n+1;
    end
    PKL_data_table = cell2table(PKL_cell);
    PKL_data_table.Properties.VariableNames = pkl_variable_names;

    DATA_for_excel_export = ...
        [(AMNIS_text_table.ObjectNumber+1),...
         AMNIS_text_table.ObjectNumber,...
         GOOD_cell_calculation,...
         PKL_data_table.Number_of_localizations,...
         PKL_data_table.Sum_of_localization_intensity,...
         PKL_data_table.Sum_of_thresholded_localization_intensity,...
         AMNIS_text_table.Intensity_MC_Ch02];
    TABLE_for_excel_export = array2table(DATA_for_excel_export,...
    'VariableNames',{'ImageNumber','ObjectNumber','GoodCell','NumberOfLocalizations','LocalizationIntensity','ThresholdedLocalizationIntensity','CellIntensity'});
    % Write data
    writetable(TABLE_for_excel_export,filename_output_xlsx,'Sheet',1,'Range','A1',"WriteRowNames",true,'WriteVariableNames',true);
    writetable(sortrows(TABLE_for_excel_export(GOOD_cell_calculation,:),4),filename_output_xlsx_good_only,'Sheet',1,'Range','A1',"WriteRowNames",true,'WriteVariableNames',true);
    
    
    DATA_for_excel_summary = ...
         [numel(AMNIS_text_table.ObjectNumber),...
         sum(GOOD_cell_calculation),...
         mean(PKL_data_table.Number_of_localizations(GOOD_cell_calculation)),...
         mean(PKL_data_table.Sum_of_localization_intensity(GOOD_cell_calculation)),...
         mean(PKL_data_table.Sum_of_thresholded_localization_intensity(GOOD_cell_calculation)),...
         mean(AMNIS_text_table.Intensity_MC_Ch02(GOOD_cell_calculation))];
    TABLE_for_excel_summary_single_condition = array2table(DATA_for_excel_summary,...
    'VariableNames',{'N_Objects','N_Good_cells','Number_of_localizations','Localization_intensity','Thresholded_Localization_intensity','Cell_intensity'});
    TABLE_for_excel_summary_single_condition = [ table({small_filename}, 'VariableNames', {'Filename'}),  TABLE_for_excel_summary_single_condition];    % Concatenate Dates In Table
    TABLE_for_excel_summary = [TABLE_for_excel_summary;TABLE_for_excel_summary_single_condition];


    % Find the objects with the average
    
    TABLE_good_candidates = TABLE_for_excel_export(GOOD_cell_calculation,:);
    rows_with_typical_number_of_foci = find(TABLE_good_candidates.NumberOfLocalizations == round(mean(TABLE_good_candidates.NumberOfLocalizations)));
%     rows_with_typical_number_of_foci = find(TABLE_good_candidates.NumberOfLocalizations == 8);
    TABLE_good_candidates = TABLE_good_candidates(rows_with_typical_number_of_foci,:);
    writetable(TABLE_good_candidates,filename_output_xlsx_good_candidates,'Sheet',1,'Range','A1',"WriteRowNames",true,'WriteVariableNames',true);

    % Possibly add
    % Load images and display them with localizations
    if show_plots
        fig = figure(pkl_file_number);
        set(gcf,'name',[small_filename ': ' num2str(round(mean(TABLE_good_candidates.NumberOfLocalizations))), ' locs']); 
        clf;
        imagestack_info = imfinfo(image_filename);
        for nth_image = 1:min(16,numel(rows_with_typical_number_of_foci))
            subplot(4,4,nth_image)
            image_number =  TABLE_good_candidates.ImageNumber(nth_image);
            localization_offset = PKL_data_table.Offset_yx(image_number,:);
            localization_positions = PKL_data_table.Localization_positions{image_number};
            imagedata = imread(image_filename,'info',imagestack_info,'index',image_number);
            imagesc(imagedata); colormap(gray); axis image;
            title(image_number);
            xticks('');
            yticks('');
            hold on;
            try
            scatter(localization_positions(:,2)+localization_offset(2),localization_positions(:,1)+localization_offset(1),'xr');
            catch
            end
            hold off;
        end
        saveas(fig,[small_filename '-' num2str(round(mean(TABLE_good_candidates.NumberOfLocalizations))), ' locs.png']);
        clf;
    end
end
% Write data
writetable(TABLE_for_excel_summary,avg_filename_output_xlsx,'Sheet',1,'Range','A1',"WriteRowNames",true,'WriteVariableNames',true);

function [cell_variable] = ConvertPythonList2cell(pythonList,intensity_minimum)
    cell_variable = cell(1,size(pythonList,2)+1);
    for n = 1:size(pythonList,2)
        cell_variable{n} = double(pythonList{n});
    end
    intensities = cell_variable{3};
    foci_to_keep_for_counting = find(intensities>intensity_minimum);
   % 'Offset_yx', 'Localization_positions', 'Localization_intensities', 'Number_of_localizations','Localization_confidences','Sum_of_localization_intensity'
    cell_variable{2} =  cell_variable{2}(foci_to_keep_for_counting,:); % Localization_positions
    cell_variable{3} =  cell_variable{3}(foci_to_keep_for_counting); % intensities
    cell_variable{4} =  numel(foci_to_keep_for_counting); % Localization_positions
    cell_variable{5} =  cell_variable{5}(foci_to_keep_for_counting); % confidence
    cell_variable{7} =  sum(cell_variable{3}); % new sum of intensities

%     tabledata = cell2table(temp_variable);
end