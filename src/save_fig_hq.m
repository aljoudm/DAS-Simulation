function save_fig_hq(fig, outdir, name)
% SAVE_FIG_HQ  Publication export: png at 300 dpi + pdf (vector axes), same name.
exportgraphics(fig, fullfile(outdir, [name '.png']), 'Resolution', 300);
exportgraphics(fig, fullfile(outdir, [name '.pdf']), 'ContentType', 'vector');
end
