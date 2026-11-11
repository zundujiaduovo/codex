function files=leo_v14_save_specs(specs,directory,name,render)
if ~exist(directory,'dir'), mkdir(directory); end
fid=fopen(fullfile(directory,[name,'.json']),'w','n','UTF-8'); assert(fid>=0);
fprintf(fid,'%s',jsonencode(specs)); fclose(fid); files={};
if render, files=leo_render_plot_specs(specs,directory); end
end
