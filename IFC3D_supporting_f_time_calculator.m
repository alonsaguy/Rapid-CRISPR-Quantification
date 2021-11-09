function [time_elapsed, time_units] = IFC3D_supporting_f_time_calculator(time_elapsed)
%% IFC3D_supporting_f_time_calculator
% Converts to the right units
    if time_elapsed < 60
        time_elapsed = round(time_elapsed,2);
        time_units = 's';
    elseif time_elapsed >= 60 && time_elapsed < 3600
        time_elapsed = round(time_elapsed/60,2);
        time_units = 'm';
    elseif time_elapsed >= 3600
        time_elapsed = round(time_elapsed/3600,2);
        time_units = 'h';
    end
end
