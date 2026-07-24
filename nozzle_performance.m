%% Simulating Rocket nozzle performance
% Author: Stephanie Zamalloa Riveros
% Description: Analyzing a 1D expansion nozzle by calculating efficiency, thrust, and impulse at given altitude ranges and applying Summerfield separation.

clear; clc; close all;

%% 1. Input Parameters (Chamber Conditions & Geometry)
Pc = 97e5;          % Chamber Pressure (Pa) 97 bar. Assumed Static and stagnation pressure are same in chamber ( StaticP)
Tc = 3573;          % Chamber Temperature (K). Assumed static and stagnation temp are same in chamber.
gamma = 1.2;       % Specific heat ratio (typical for LOX/RP-1)
MW = 0.0216;         % Molecular weight of exhaust products (kg/mol).Molecular weight of the fuel
At = 0.06;         % Throat Area (m^2). Its the A*
Ae_At_ratio = 16;   % Nozzle Expansion Area Ratio (Ae/At) 
%Points:
% - Like chamber pressure Tc is treated as the stagnation temperature Since the kinetic energy of the fluid in the  
%   chamber is negligible , the static temperature matches this total
%   temperature baseline. As the fluid accelerates through the nozzle, that thermal energy is converted into kinetic energy,
%   causing the static temperature to drop rapidly as velocity increases. 
% 
% Universal Gas Constant
R_universal = 8.314; 
R_spec = R_universal / MW; % Specific gas constant (J/kg*K)

%% 2. Environmental Conditions (Altitude Vector)
% Simulating atmospheric pressure from sea level (0m) to vacuum (40,000m)
altitudes = 0:500:40000; % Altitude array in meters
[~, ~, Pa_vector, ~] = atmosisa(altitudes); % Atmospheric ISO Standard Atmosphere. Pulls real Earth air pressure for our 81 altitude steps,skipping temperature and density.
                                                                                   
%% 3. Nozzle Exit Calculations (Isentropic Relations)
% Characteristic Velocity (C-star) - indicator of combustion efficiency
c_star = sqrt(gamma * R_spec * Tc) / (gamma * sqrt((2 / (gamma + 1))^((gamma + 1) / (gamma - 1))));

% Mass Flow Rate (dot_m) - constant for choked flow at throat
dot_m = (At * Pc * gamma * sqrt((2 / (gamma + 1))^((gamma + 1) / (gamma - 1)))) / sqrt(gamma * R_spec * Tc); %It calculates total propellant mass burned per second through the chocked throat.
                           
% Exit Mach Number (Me) using an implicit area-ratio solver
A_func = @(M) (1./M) .* ((2/(gamma+1)) .* (1 + 0.5*(gamma-1).*M.^2)).^((gamma+1)/(2*(gamma-1))) - Ae_At_ratio;
Me = fzero(A_func, 3.5); % Start guess at Mach 3.5 for supersonic nozzle. Uses a numerical solver to find our exact supersonic exit Mach
% number because the equation can't be solved with basic algebra.

% Exit Pressure (Pe) and Exit Temperature (Te)
Pe = Pc / (1 + 0.5 * (gamma - 1) * Me^2)^(gamma / (gamma - 1));
Te = Tc / (1 + 0.5 * (gamma - 1) * Me^2);

% Exit Velocity (Ve)
Ve = Me * sqrt(gamma * R_spec * Te);

%% 4. Thrust and Specific Impulse with Summerfield Separation Check
Ae = At * Ae_At_ratio;

% Initialize empty arrays to store corrected results
Thrust = zeros(size(altitudes)); %  Pre-allocates an empty 81 slot array to hold our thrust values efficiently.
Isp = zeros(size(altitudes));
separated_status = false(size(altitudes)); % Tracks True/False for separation

% Loop through each altitude to check the local ambient pressure
for i = 1:length(altitudes)
    Pa = Pa_vector(i);
    
    % Summerfield Criterion Check
    if Pe <= 0.35 * Pa % If true, outside air pressure is high enough to crush the exhaust plume inside the nozzle Less or equal 35% of the outside pressure.
        % FLOW IS SEPARATED
        separated_status(i) = true;
        Thrust(i) = dot_m * Ve; %Pressure thrust component drops close to zero
    else
        % FLOW IS NORMAL (ATTACHED)
        separated_status(i) = false;
        Thrust(i) = (dot_m * Ve) + (Pe - Pa) * Ae; %Full ideal rocket equation used when flow stays safely attached to the nozzle walls.
    end
    
    % Calculate Isp for this altitude step
    Isp(i) = Thrust(i) / (dot_m * 9.81);
end

% Find the exact altitude where separation stops
safe_indices = find(separated_status == false);
if ~isempty(safe_indices)
    transition_altitude = altitudes(safe_indices(1));
    fprintf('Alert: Nozzle flow separates below %.0f meters.\n', transition_altitude); %If 0 meters=nozzle never separates
else
    fprintf('Alert: Nozzle flow is separated at ALL simulated altitudes.\n');
end

%% 5. Data Organization (The Professional Way)
resultsTable = table(altitudes', Pa_vector', Thrust', Isp', ...
    'VariableNames', {'Altitude_m', 'Ambient_Pressure_Pa', 'Thrust_N', 'Isp_s'});

%% 6. Engineering Visualization
figure('Color', [1 1 1]);

% Plot 1: Thrust vs Altitude
subplot(2, 1, 1);
plot(altitudes/1000, Thrust/1000, 'k-', 'LineWidth', 2); hold on;

% Calculate the max thrust value first
y_max = max(Thrust/1000);

% Highlight the separated region in red shading if a transition exists
if exist('transition_altitude', 'var')
    fill([0 transition_altitude transition_altitude 0]/1000, [0 0 y_max y_max], ...
         [1 0.8 0.8], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
end

grid on;
title('Nozzle Performance with Summerfield Separation Regime');
ylabel('Thrust (kN)');
xlabel('Altitude (km)');
legend('Thrust Curve', 'Separated Flow Zone', 'Location', 'southeast');

% Plot 2: Isp vs Altitude
subplot(2, 1, 2);
plot(altitudes/1000, Isp, 'b-', 'LineWidth', 2); hold on;
grid on;
ylabel('Specific Impulse, I_{sp} (s)');
xlabel('Altitude (km)');