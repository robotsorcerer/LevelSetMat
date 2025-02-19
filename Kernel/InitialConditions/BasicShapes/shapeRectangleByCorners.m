function data = shapeRectangleByCorners(grid, lower, upper)
% shapeRectangleByCorners: implicit surface function for a (hyper)rectangle.
%
%   data = shapeRectangleByCorners(grid, lower, upper)
%
% Creates an implicit surface function (close to signed distance)
%   for a coordinate axis aligned (hyper)rectangle specified by its
%   lower and upper corners.
%
% Can be used to create intervals, slabs and other unbounded shapes
%   by choosing components of the corners as +-Inf.
%
% The default parameters for shapeRectangleByCenter and
%   shapeRectangleByCorners produce different rectangles.
%
% Input Parameters:
%
%   grid: Grid structure (see processGrid.m for details).
%
%   lower: Vector specifying the lower corner.  May be a scalar, in
%   which case the scalar is multiplied by a vector of ones of the
%   appropriate length.  Defaults to 0.
%
%   upper: Vector specifying the upper corner.  May be a scalar, in which
%   case the scalar is multiplied by a vector of ones of the appropriate
%   length.  Defaults to 1.  Note that all(lower < upper) must hold,
%   otherwise the implicit surface will be empty.
%
% Output Parameters:
%
%   data: Output data array (of size grid.size) containing the implicit
%   surface function.

% Copyright 2004 Ian M. Mitchell (mitchell@cs.ubc.ca).
% This software is used, copied and distributed under the licensing
%   agreement contained in the file LICENSE in the top directory of
%   the distribution.
%
% Ian Mitchell, 6/23/04
% $Date: 2009-09-03 16:34:07 -0700 (Thu, 03 Sep 2009) $
% $Id: shapeRectangleByCorners.m 44 2009-09-03 23:34:07Z mitchell $

%---------------------------------------------------------------------------
% Default parameter values.
if(nargin < 2)
  lower = zeros(grid.dim, 1);
elseif(numel(lower) == 1)
  lower = lower * ones(grid.dim, 1);
end
if(nargin < 3)
  upper = ones(grid.dim, 1);
elseif(numel(lower) == 1)
  upper = upper * ones(grid.dim, 1);
end

%---------------------------------------------------------------------------
% Implicit surface function calculation.
%   This is basically the intersection (by max operator) of halfspaces.
%   While each halfspace is generated by a signed distance function,
%   the resulting intersection is not quite a signed distance function.
data = max(grid.xs{1} - upper(1), lower(1) - grid.xs{1});
for i = 2 : grid.dim
  data = max(data, grid.xs{i} - upper(i));
  data = max(data, lower(i) - grid.xs{i});
end

%---------------------------------------------------------------------------
% Warn the user if there is no sign change on the grid
%  (ie there will be no implicit surface to visualize).
if(all(data(:) < 0) || (all(data(:) > 0)))
  warning([ 'Implicit surface not visible because function has ' ...
            'single sign on grid' ]);
end
