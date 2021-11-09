function IFC3D_supporting_f_cif_to_tif(varargin)
%IFC3D_SUPPORTING_F_CIF_TO_TIF This function will convert cif files into
% tif files
%   Running this function without any inputs will convert all files in a
%   folder. Running this file with any number of strings 
number_of_inputs = nargin;
switch number_of_inputs
    case 0
        all_files = dir('*.cif');
        number_of_files = numel(all_files);
        files_for_conversion = cell(1,number_of_files);
        for input_number = 1:number_of_files
            files_for_conversion{input_number} = all_files(input_number).name;
        end
    case 1
        if isstring(varargin) || ischar(varargin)
            number_of_files = 1;
            files_for_conversion = {varargin}; 
        elseif iscell(varargin)
            varargin=varargin{1};
            number_of_files = numel(varargin);
            files_for_conversion = cell(1,number_of_files);
            for input_number = 1:number_of_files
                files_for_conversion{input_number} = char(varargin(input_number));
            end
        end
    otherwise
        number_of_files = nargin;
        files_for_conversion = cell(1,number_of_files);
        for input_number = 1:number_of_files
            files_for_conversion{input_number} = char(varargin(input_number));
        end
end
% number_of_files
% files_for_conversion
% For converting data as a mat file.
user_settings.data_folder = [cd '\'];
user_settings.export_folder = [cd, '\'];
user_settings.bioformats_path = ['C:\Users\', getenv('USERNAME') '\Documents\MATLAB\bfmatlab']; %#ok<*NASGU>

user_settings.cif_reader.channels_to_import = [2];
user_settings.cif_reader.maximum_object_to_load = inf;
user_settings.cif_reader.import_masks = false;
% For exporting data as TIFs;
user_settings.export.objects_for_export = 'all';
user_settings.export.channels_to_export = [2];
user_settings.export.noisy_background_option = true;
% Skip the file checks.
user_settings.health.file_check = false;

    for filenumber = 1:number_of_files
        filename = files_for_conversion{filenumber};
        IFC3D_cif_reader(filename(1:end-4),user_settings);
        IFC3D_tif_creator(filename(1:end-4),user_settings);
        delete([user_settings.export_folder, filename(1:end-4), '_image_data.mat'])
    end
end