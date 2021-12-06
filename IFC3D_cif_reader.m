function IFC3D_cif_reader(varargin)
%% IFC3D_cif_reader: main
% This file converts the image data contained in ".cif" data into the ".mat" format.
% FUNCTION INPUTS: variable
%   If no input is given,  filename = IFC3D_tutorial_data; user_settings = IFC3D_tutorial_settings
%   If 1 input is given,   filename = input; user_settings = IFC3D_settings 
%   If 2+ inputs are given, filename = input(1); user_settings = input(2)
% FUNCTION OUTPUTS: none
%   A .mat file containing the image data and some metadata will be created.
%   An optional second file containing the image-mask data and some metadata will be created.
% CONTAINED FUNCTIONS:
%   f_detect_bioformats(fileID, user_settings)
%   f_get_image_from_bioformats(reader, series_number, channel_number)
% REQUIRED ADDITIONAL FUNCTIONS:
%   IFC3D_supporting_f_check_for_file  
%   IFC3D_supporting_f_time_calculator

%% Load Settings
% Open the logger file and start function timer.
fileID = fopen('IFC3D_logger.txt','a');
tic;
fprintf(fileID,[char(datetime), ' started cif_reader \n']);

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
elseif nargin >= 2
    filename = varargin{1};
    if isstruct(varargin{2})
        user_settings = varargin{2};
    else
        user_settings = load(varargin{2});
    end
    fprintf(fileID,' custom settings path loaded \n');
end

% Create filenames for loading and saving data
filename_cif = [filename, '.cif']; 
filename_images = [filename, '_image_data'];
filename_masks = [filename, '_mask_data'];


%% Detect for required files and functions.
f_detect_bioformats(fileID, user_settings);
[exists_cif,~]    = IFC3D_supporting_f_check_for_file(user_settings.data_folder,filename,'.cif',false);
% [exists_image, ~] = IFC3D_supporting_f_check_for_file(user_settings.export_folder,[filename, '_image_data'],'.mat',false);
% [exists_masks, ~] = IFC3D_supporting_f_check_for_file(user_settings.export_folder,[filename, '_mask_data'],'.mat',false);
    % A future version will determine if identical settings were used previously to load a file
if ~all(exists_cif)
    fprintf(fileID,[char(datetime), ' ***Error: required file missing*** \n']);
    fclose(fileID);
    error('missing cif file');
end

%% Prepare to load files
java.lang.Runtime.getRuntime.maxMemory;
visual_reader = bfGetReader(strcat(user_settings.data_folder, '\',filename_cif));
visual_reader = loci.formats.Memoizer(visual_reader);
omeMeta = visual_reader.getMetadataStore();

% Load the metafile data
number_of_channels = omeMeta.getChannelCount(0);
number_of_objects = omeMeta.getImageCount()/2;

% Prepare empty variables
image_data = cell(number_of_objects,number_of_channels);
if user_settings.cif_reader.import_masks
    mask_data = cell(number_of_objects,number_of_channels);
else
    mask_data = {};
end
imagesize_rows = int16(zeros(number_of_objects,1));
imagesize_cols  = int16(zeros(number_of_objects,1));

% Determine which channels and objects will be used
if strcmp(user_settings.cif_reader.channels_to_import,'all')
    channels_for_saving_images = unique(1:number_of_channels);
else
    channels_for_saving_images = user_settings.cif_reader.channels_to_import;
end
Objects_to_store_image = 1:min([number_of_objects,user_settings.cif_reader.maximum_object_to_load]);
    % A future version will allow for specific objects to be loaded.

%% Load images of objects
for Object_number = Objects_to_store_image
    for channel_number = channels_for_saving_images
        if isempty(image_data{Object_number,channel_number}) || isempty(mask_data{Object_number,channel_number})
            image_data{Object_number,channel_number} = uint16(f_get_image_from_bioformats(visual_reader, 2*(Object_number-1), channel_number));
            % Mask importing settings
            if user_settings.cif_reader.import_masks
                mask_data{Object_number,channel_number}  = logical(f_get_image_from_bioformats(visual_reader, 2*(Object_number-1)+1, channel_number));
            end
        else
            continue
        end
    end
    % This only needs to happen once, so we do it on the last channel_number used
    imagesize_rows(Object_number) = size(image_data{Object_number,channel_number},1);
    imagesize_cols(Object_number) = size(image_data{Object_number,channel_number},2);
end

%% Wrap up
visual_reader.close();

% Save data and report
if user_settings.cif_reader.import_masks
    save([user_settings.export_folder, filename_images,'.mat'],'filename','image_data','imagesize_rows','imagesize_cols','number_of_objects','number_of_channels','channels_for_saving_images','-v7.3');
    save([user_settings.export_folder, filename_masks,'.mat'], 'filename','mask_data', 'imagesize_rows','imagesize_cols','number_of_objects','number_of_channels','channels_for_saving_images','-v7.3');
    fprintf(fileID,' images and masks saved \n');
else 
    save([user_settings.export_folder, filename_images,'.mat'],'filename','image_data','imagesize_rows','imagesize_cols','number_of_objects','number_of_channels','channels_for_saving_images','-v7.3');
    fprintf(fileID,' images saved \n');
end

% Ending time measurement
time_elapsed = toc;
[time_elapsed, time_units] = IFC3D_supporting_f_time_calculator(time_elapsed);
fprintf(fileID,[' time elapsed: ', num2str(time_elapsed), ' ', time_units ' \n']);

% Close logger
fclose(fileID);

%% Functions
% Start of detect bioformats
    function f_detect_bioformats(fileID, user_settings)
    %% IFC3D_cif_reader: f_detect_bioformats
    % This will see if you have bioforamts plugin
        try
            addpath(user_settings.bioformats_path);
            import org.apache.log4j.Logger;
            import org.apache.log4j.Level;
            Logger.getRootLogger().setLevel(Level.WARN);
        catch
            fprintf(fileID,[char(datetime), ' ***Error: bioformats not found*** \n']);
            fclose(fileID);
            disp({'Must install Bio-formats plugin';'https://docs.openmicroscopy.org/bio-formats/5.8.2/users/matlab/index.html'});
            error('need to install bformats matlab plugin');
        end
    end
% End of detect bioformats

% Start of get image from bioformats
    function [loaded_image] = f_get_image_from_bioformats(reader, series_number, channel_number)
        % set which cell we are reading
        reader.setSeries(series_number);
        % read image 
        iPlane = reader.getIndex(0, channel_number-1, 0) + 1;
        loaded_image = bfGetPlane(reader, iPlane);    
    end
% End of get image from bioformats
end