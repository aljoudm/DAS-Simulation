function mark_events(ax, ev, ytop, labels)
% MARK_EVENTS  Mark event positions (km) on an image axes: white triangle at the
%              top edge and (optionally) a white label next to it.
if nargin < 4, labels = true; end
for i = 1:numel(ev)
    plot(ax, ev(i).z0/1e3, ytop, 'v', 'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'k', ...
         'MarkerSize', 7, 'Clipping', 'off');
    if labels
        text(ax, ev(i).z0/1e3 + 0.2, ytop*0.80, ev(i).type, 'Color', 'w', ...
             'FontWeight', 'bold', 'FontSize', 10, 'VerticalAlignment', 'top');
    end
end
end
