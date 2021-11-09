function IFC3D_tif_creator(varargin)
%% IFC3D_tif_creator: main
% This file converts the image data contained in the ".mat" data into ".tif" image stacks..
% FUNCTION INPUTS: variable
%   If no input is given,  filename = IFC3D_tutorial_data; user_settings = IFC3D_tutorial_settings
%   If 1 input is given,   filename = input; user_settings = IFC3D_settings 
%   If 2 inputs are given, filename = input(1); user_settings = input(2)
% FUNCTION OUTPUTS: none
%   Image data of the specified type.
% CONTAINED FUNCTIONS: none.
% REQUIRED ADDITIONAL FUNCTIONS:
%   IFC3D_supporting_f_check_for_file  
%   IFC3D_supporting_f_time_calculator

%% Load Settings
% Open the logger file and start function timer.
fileID = fopen('IFC3D_logger.txt','a');
tic;
fprintf(fileID,[char(datetime), ' started tif_creator \n']);

% Load settings file to use.
if nargin == 0
    filename = 'IFC3D_tutorial_data';
    [exists_settings,~] = IFC3D_supporting_f_check_for_file(cd,'IFC3D_tutorial_settings','.mat',false);
    if ~exists_settings
        fprintf(fileID,[char(datetime), ' ***Error: required settings file missing*** \n']);
        fclose(fileID);
        error('missing settings file');
    end
    user_settings = load('IFC3D_tutorial_settings.mat');
    fprintf(fileID,' tutorial settings loaded \n');
elseif nargin == 1
    filename = varargin{1};
    user_settings = load('IFC3D_settings.mat');
    fprintf(fileID,' settings file loaded \n');
elseif nargin == 2
    filename = varargin{1};
    if isstruct(varargin{2})
        user_settings = varargin{2};
    else
        user_settings = load(varargin{2});
    end
    fprintf(fileID,' custom settings path loaded \n');
end

% Create filenames for loading and saving data
filename_calibration_objects = [filename, '_object_types'];
filename_image_data = [filename, '_image_data'];

%% Detect for required files and functions.
if user_settings.health.file_check
    [exists_calibration_objects,~]    = IFC3D_supporting_f_check_for_file(user_settings.data_folder,filename_calibration_objects,'.mat',true);
    [exists_image_data,~]    = IFC3D_supporting_f_check_for_file(user_settings.data_folder,filename_image_data,'.mat',false);
    if ~all([exists_calibration_objects,exists_image_data])
        fprintf(fileID,[char(datetime), ' ***Error: required file missing*** \n']);
        fclose(fileID);
        error('missing essential file');
    end
end
%% Prepare and load files
% Load imagedata
load([user_settings.export_folder, filename_image_data, '.mat'],'image_data','imagesize_rows','imagesize_cols','number_of_objects','number_of_channels');

switch user_settings.export.objects_for_export
    case 'all'
        objects_for_export = (1:number_of_objects)';
    case 'calibration only'
        % Load calibration object info
        load([user_settings.export_folder, filename_calibration_objects, '.mat'],'calibration_objects');
        objects_for_export = calibration_objects;
    case 'non-calibration only'
        % Load calibration object info
        load([user_settings.export_folder, filename_calibration_objects, '.mat'],'non_calibration_objects');
        objects_for_export = [];
        all_fields = fieldnames(non_calibration_objects);
        for i = 1:numel(all_fields)
            objects_for_export = [objects_for_export;non_calibration_objects.(all_fields{i})]; %#ok<AGROW>
        end
        objects_for_export = unique(objects_for_export);
    otherwise
        load([user_settings.export_folder, filename_calibration_objects, '.mat'],'non_calibration_objects');
        objects_for_export = non_calibration_objects.(user_settings.export.objects_for_export);
    % here we need to compare to the specifics 
end


% Determine which channels and objects will be used
if strcmp(user_settings.export.channels_to_export,'all')
    channels_for_saving_images = unique(1:number_of_channels);
else
    channels_for_saving_images = user_settings.export.channels_to_export;
end

%% Prepare to export data

%Prepare empty matricies
row_size = prctile(imagesize_rows(objects_for_export),99);
col_size = prctile(imagesize_cols(objects_for_export),99);
expanded_image = uint16(zeros(row_size,col_size));

% Detect and delete existing files
for nth_channel = channels_for_saving_images
filename_output_stack = [filename, '_', user_settings.export.objects_for_export, '_ch', num2str(nth_channel)];
[exists_imagedata,~]    = IFC3D_supporting_f_check_for_file(user_settings.export_folder,filename_output_stack,'.tif',true);
    if exists_imagedata
        delete([user_settings.export_folder, filename_output_stack, '.tif']);
    end
end

% Export images
for nth_image = 1:numel(objects_for_export)
    object_number = objects_for_export(nth_image);
    for nth_channel = channels_for_saving_images
        loaded_image = image_data{object_number,nth_channel};
        [N,edges,~] =histcounts(loaded_image(:),'BinMethod','integers');
        background = mean(edges(N==max(N))+.5);
        row_extent = min([imagesize_rows(object_number),row_size]);
        col_extent = min([imagesize_cols(object_number),col_size]);
        if ~user_settings.export.noisy_background_option
            expanded_image = 0*expanded_image+background;
        elseif user_settings.export.noisy_background_option
%             noise_setting = 1/3*(background - (edges(1)+.5));
            pixels_less_than_background = loaded_image(loaded_image<background);
            pixels_equal_to_background = loaded_image(loaded_image==background);
            artificial_pixels_larger_than_background = 2*background-pixels_less_than_background;
            noise_setting = std(single([artificial_pixels_larger_than_background;pixels_equal_to_background;pixels_less_than_background]));
            expanded_image = uint16(background + noise_setting*randn(row_size,col_size));
        end
        expanded_image(1:row_extent,1:col_extent) = loaded_image(1:row_extent,1:col_extent);
%         imagesc(expanded_image)
        imwrite(expanded_image,[user_settings.export_folder, filename, '_', user_settings.export.objects_for_export, '_ch', num2str(nth_channel), '.tif'],'writemode','append')
    end
end

%% Wrap up
% Save data and report
% ***********ADD SAVING DATA HERE**************
fprintf(fileID, ' images saved \n');
% Ending time measurement
time_elapsed = toc;
[time_elapsed, time_units] = IFC3D_supporting_f_time_calculator(time_elapsed);
fprintf(fileID,[' time elapsed: ', num2str(time_elapsed), ' ', time_units ' \n']);

% Close logger
fclose(fileID);
end