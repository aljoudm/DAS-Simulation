function axs = plot_event_zooms(parent, tileIdx, Z, zw, t, ev, clims, cmap, cblabel, letters)
% PLOT_EVENT_ZOOMS  One row of zoomed image panels, one per event, with ONE shared
%   colour bar (same colour scale for all panels).
%     Z{i}  [Nt x Nz_i] image data     zw{i}  distance from event [m]    t  time [s]
tl2 = tiledlayout(parent, 1, numel(Z), 'TileSpacing', 'compact', 'Padding', 'compact');
tl2.Layout.Tile = tileIdx;
axs = gobjects(1, numel(Z));
for i = 1:numel(Z)
    ax = nexttile(tl2);
    imagesc(ax, zw{i}, t, Z{i});
    axis(ax, 'xy'); clim(ax, clims); grid(ax, 'off');
    xticks(ax, [-1 0 1] * 0.5 * max(abs(zw{i})));
    if ~isempty(cmap), colormap(ax, cmap); end
    xlabel(ax, 'distance from event [m]');
    if i == 1, ylabel(ax, 'time [s]'); else, set(ax, 'YTickLabel', []); end
    panel_label(ax, sprintf('%s %s, %.0f km', letters{i}, ev(i).type, ev(i).z0/1e3));
    axs(i) = ax;
end
cb = colorbar(axs(end)); cb.Layout.Tile = 'east'; cb.Label.String = cblabel;
end
