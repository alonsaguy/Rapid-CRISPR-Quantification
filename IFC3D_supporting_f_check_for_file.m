function [exists, filename] = IFC3D_supporting_f_check_for_file(data_folder,basename,extension,silent_mode)
%% IFC3D_cif_reader: f_check_for_file
% Checks if a file exists or not in the directory and outputs the filename.
    % Because we remove '\\' later, this would make the code not work on network drives. This prevents that.
if strcmp(data_folder(1:2),'\\')
    data_folder = ['\' data_folder];
end
exists = isfile(strrep(char(strcat(data_folder, '\', basename, extension)),'\\','\'));
matching_files = dir(strrep(char(strcat(data_folder, '\', basename, extension)),'\\','\'));
if isempty(matching_files)
    filename = nan;
    if ~silent_mode
        disp({'No file matches: ';char(strcat(data_folder,'\', basename, extension))});
    end
elseif numel(matching_files)==1
    filename = matching_files.name;
else
    exists = false;
    filename = nan;
    if ~silet_mode
        disp({'More than one file matches the description:';strrep(char(strcat(data_folder, '\', basename, extension)),'\\','\')});
    end
end
end