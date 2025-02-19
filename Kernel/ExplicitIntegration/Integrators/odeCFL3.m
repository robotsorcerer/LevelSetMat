function [ t, y, schemeData ] = ...
                            odeCFL3(schemeFunc, tspan, y0, options, schemeData)
% odeCFL3: integrate a CFL constrained ODE (eg a PDE by method of lines).
%
% [ t, y, schemeData ] = odeCFL3(schemeFunc, tspan, y0, options, schemeData)
%
% Integrates a system forward in time by CFL constrained timesteps
%   using a third order Total Variation Diminishing (TVD) Runge-Kutta
%   (RK) scheme.  Details can be found in O&F chapter 3.
%
% parameters:
%   schemeFunc	 Function handle to a CFL constrained ODE system
%                  (typically an approximation to an HJ term, see below).
%   tspan        Range of time over which to integrate (see below).
%   y0           Initial condition vector
%                  (typically the data array in vector form).
%   options      An option structure generated by odeCFLset
%                  (use [] as a placeholder if necessary).
%   schemeData   Structure passed through to schemeFunc.
%
%
%   t            Output time(s) (see below).
%   y            Output state (see below).
%   schemeData   Output version of schemeData (see below).
%
% A CFL constrained ODE system is described by a function with prototype
%
%        [ ydot, stepBound ] = schemeFunc(t, y, schemeData)
%
%   where t is the current time, y the current state vector and
%   schemeData is passed directly through.  The output stepBound
%   is the maximum allowed time step that will be taken by this function
%   (typically the option parameter factorCFL will choose a smaller step size).
%
% The time interval tspan may be given as
%   1) A two entry vector [ t0 tf ], in which case the output will
%      be scalar t = tf and a row vector y = y(tf).
%   2) A vector with three or more entries, in which case the output will
%      be column vector t = tspan and each row of y will be the solution
%      at one of the times in tspan.  Unlike Matlab's ode suite routines,
%      this version just repeatedly calls version (1), so it is not
%      particularly efficient.
%
% Note that using this routine for integrating HJ PDEs will usually
%   require that the data array be turned into a vector before the call
%   and reshaped into an array after the call.  Option (2) for tspan should
%   not be used in this case because of the excessive memory requirements
%   for storing solutions at multiple timesteps.
%
% The output version of schemeData will normally be identical to the input
%   version, and therefore can be ignored.  However, if a PostTimestep
%   routine is used (see odeCFLset) then schemeData may be modified during
%   integration, and the version of schemeData at tf is returned in this
%   output argument.

% Copyright 2005 Ian M. Mitchell (mitchell@cs.ubc.ca).
% This software is used, copied and distributed under the licensing
%   agreement contained in the file LICENSE in the top directory of
%   the distribution.
%
% Ian Mitchell, 5/14/03.
% Calling parameters modified to more closely match Matlab's ODE suite
%   Ian Mitchell, 2/14/04.
% Modified to allow vector level sets.  Ian Mitchell, 12/13/04.
% Modified to add terminalEvent option, Ian Mitchell, 1/30/05.

  %---------------------------------------------------------------------------
  % How close (relative) do we need to be to the final time?
  small = 100 * eps;

  %---------------------------------------------------------------------------
  % Make sure we have the default options settings
  if((nargin < 4) | isempty(options))
    options = odeCFLset;
  end

  %---------------------------------------------------------------------------
  % This routine includes multiple substeps, and the CFL restricted timestep
  %   size is chosen on the first substep.  Subsequent substeps may violate
  %   CFL slightly; how much should be allowed before generating a warning?

  % This choice allows 20% more than the user specified CFL number,
  %   capped at a CFL number of unity.  The latter cap may cause
  %   problems if the user is using a very aggressive CFL number.
  safetyFactorCFL = min(1.0, 1.2 * options.factorCFL);

  %---------------------------------------------------------------------------
  % Number of timesteps to be returned.
  numT = length(tspan);

  %---------------------------------------------------------------------------
  % If we were asked to integrate forward to a final time.
  if(numT == 2)

    % Is this a vector level set integration?
    if(iscell(y0))
      numY = length(y0);

      % We need a cell vector form of schemeFunc.
      if(iscell(schemeFunc))
        schemeFuncCell = schemeFunc;
      else
        [ schemeFuncCell{1:numY} ] = deal(schemeFunc);
      end

    else
      % Set numY, but be careful: ((numY == 1) & iscell(y0)) is possible.
      numY = 1;

      % We need a cell vector form of schemeFunc.
      schemeFuncCell = { schemeFunc };

    end

    t = tspan(1);
    steps = 0;
    startTime = cputime;
    stepBound = zeros(numY, 1);
    ydot = cell(numY, 1);
    y = y0;

    while(tspan(2) - t >= small * abs(tspan(2)))

      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      % Approximate the derivative and CFL restriction.
      for i = 1 : numY
        [ ydot{i}, stepBound(i), schemeData ] = ...
                                    feval(schemeFuncCell{i}, t, y, schemeData);

        % If this is a vector level set, rotate the lists of vector arguments.
        if(iscell(y))
          y = y([ 2:end, 1 ]);
        end

        if(iscell(schemeData))
          schemeData = schemeData([ 2:end, 1 ]);
        end
      end

      % Determine CFL bound on timestep, but not beyond the final time.
      %   For vector level sets, use the most restrictive stepBound.
      %   We'll use this fixed timestep for all substeps.
      deltaT = min([ options.factorCFL * stepBound; ...
                     tspan(2) - t; options.maxStep ]);

      % Take the first substep.
      t1 = t + deltaT;
      if(iscell(y))
        y1 = cell(numY, 1);
        for i = 1 : numY
          y1{i} = y{i} + deltaT * ydot{i};
        end
      else
        y1 = y + deltaT * ydot{1};
      end

      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      % Second substep: Forward Euler from t_{n+1} to t_{n+2}.

      % Approximate the derivative.
      %   We will also check the CFL condition for gross violation.
      for i = 1 : numY
        [ ydot{i}, stepBound(i), schemeData ] = ...
                                 feval(schemeFuncCell{i}, t1, y1, schemeData);

        % If this is a vector level set, rotate the lists of vector arguments.
        if(iscell(y1))
          y1 = y1([ 2:end, 1 ]);
        end

        if(iscell(schemeData))
          schemeData = schemeData([ 2:end, 1 ]);
        end
      end

      % Check CFL bound on timestep:
      %   If the timestep chosen on the first substep violates
      %   the CFL condition by a significant amount, throw a warning.
      %   For vector level sets, use the most restrictive stepBound.
      % Occasional failure should not cause too many problems.
      if(deltaT > min(safetyFactorCFL * stepBound))
        violation = deltaT / stepBound;
        warning('Second substep violated CFL; effective number %f', violation);
      end

      % Take the second substep.
      t2 = t1 + deltaT;
      if(iscell(y1))
        y2 = cell(numY, 1);
        for i = 1 : numY
          y2{i} = y1{i} + deltaT * ydot{i};
        end
      else
        y2 = y1 + deltaT * ydot{1};
      end

      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      % Combine t_n and t_{n+2} to get approximation at t_{n+1/2}
      tHalf = 0.25 * (3 * t + t2);
      if(iscell(y2))
        yHalf = cell(numY, 1);
        for i = 1 : numY
          yHalf{i} = 0.25 * (3 * y{i} + y2{i});
        end
      else
        yHalf = 0.25 * (3 * y + y2);
      end

      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      % Third substep: Forward Euler from t_{n+1/2} to t_{n+3/2}.

      % Approximate the derivative.
      %   We will also check the CFL condition for gross violation.
      for i = 1 : numY
        [ ydot{i}, stepBound(i), schemeData ] = ...
                            feval(schemeFuncCell{i}, tHalf, yHalf, schemeData);

        % If this is a vector level set, rotate the lists of vector arguments.
        if(iscell(yHalf))
          yHalf = yHalf([ 2:end, 1 ]);
        end

        if(iscell(schemeData))
          schemeData = schemeData([ 2:end, 1 ]);
        end
      end

      % Check CFL bound on timestep:
      %   If the timestep chosen on the first substep violates
      %   the CFL condition by a significant amount, throw a warning.
      %   For vector level sets, use the most restrictive stepBound.
      % Occasional failure should not cause too many problems.
      if(deltaT > min(safetyFactorCFL * stepBound))
        violation = deltaT / stepBound;
        warning('Third substep violated CFL; effective number %f', violation);
      end

      % Take the third substep.
      tThreeHalf = tHalf + deltaT;
      if(iscell(yHalf))
        yThreeHalf = cell(numY, 1);
        for i = 1 : numY
          yThreeHalf{i} = yHalf{i} + deltaT * ydot{i};
        end
      else
        yThreeHalf = yHalf + deltaT * ydot{1};
      end

      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      % If there is a terminal event function registered, we need
      %   to maintain the info from the last timestep.
      if(~isempty(options.terminalEvent))
        yOld = y;
        tOld = t;
      end

      % Combine t_n and t_{n+3/2} to get third order approximation of t_{n+1}.
      t = (1/3) * (t + 2 * tThreeHalf);
      if(iscell(yThreeHalf))
        for i = 1 : numY
          y{i} = (1/3) * (y{i} + 2 * yThreeHalf{i});
        end
      else
        y = (1/3) * (y + 2 * yThreeHalf);
      end

      steps = steps + 1;

      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      % If there is one or more post-timestep routines, call them.
      if(~isempty(options.postTimestep))
        [ y, schemeData ] = odeCFLcallPostTimestep(t, y, schemeData, options);
      end

      % If we are in single step mode, then do not repeat.
      if(strcmp(options.singleStep, 'on'))
        break;
      end

      % If there is a terminal event function, establish initial sign
      %   of terminal event vector.
      if(~isempty(options.terminalEvent))

        [ eventValue, schemeData ] = ...
               feval(options.terminalEvent, t, y, tOld, yOld, schemeData);

        if((steps > 1) && any(sign(eventValue) ~= sign(eventValueOld)))
          break;
        else
          eventValueOld = eventValue;
        end
      end

    end

    endTime = cputime;

    if(strcmp(options.stats, 'on'))
      fprintf('\t%d steps in %g seconds from %g to %g\n', ...
              steps, endTime - startTime, tspan(1), t);
    end

  %---------------------------------------------------------------------------
  elseif(numT > 2)
    % If we were asked for the solution at multiple timesteps.
    [ t, y, schemeData ] = ...
     odeCFLmultipleSteps(@odeCFL3, schemeFunc, tspan, y0, options, schemeData);

  %---------------------------------------------------------------------------
  else
    % Malformed time span.
    error('tspan must contain at least two entries');
  end
