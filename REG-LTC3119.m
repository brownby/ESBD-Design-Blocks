function Result = LTC3119(Vin, Vout, Iload, varargin)
%https://www.analog.com/media/en/technical-documentation/data-sheets/3119fb.pdf
    if (length(Vin) == 1)
        Vin_min = Vin;
        Vin_max = Vin;
    elseif (length(Vin) == 2)
        Vin_min = Vin(1);
        Vin_max = Vin(2);
    else
        error("Vin must contain 1 or 2 values");
    end
    if (length(Iload) == 1)
        Iload_boost = Iload;
        Iload_buck = Iload;
    elseif (length(Iload) == 2)
        Iload_boost = Iload(1);
        Iload_buck = Iload(2);
    else
        error("Iload must contain 1 or 2 values");
    end
    
    if any(Vin < 2.5 | Vin > 18)
        error("Vin must be in range [2.5 18] [V]");
    end
    if (Vout < 0.8) || (Vout > 18)
        error("Vout must be in range [0.8 18] [V]");
    end
    if any(Iload < 0 | Iload > 5)
        error("Iload must be in range [0 5] [A]");
    end

    p = inputParser;
    addParameter(p,'Fsw',1e6);
    addParameter(p,'Vpp',-1);
    addParameter(p,'Cout',-1);
    addParameter(p,'Ipp',-1);
    addParameter(p,'Lsw',-1);
    parse(p,varargin{:});
    
    Fsw = p.Results.Fsw;
    if (p.Results.Vpp ~= -1)
        Vpp = p.Results.Vpp;
    elseif (p.Results.Cout ~= -1)
        Cout = p.Results.Cout;
    else
        error("Set Vpp or Cout");
    end
    
    if (p.Results.Ipp ~= -1)
        Ipp = p.Results.Ipp;
    elseif (p.Results.Lsw ~= -1)
        Lsw = p.Results.Lsw;
    else
        error("Set Ipp or Lsw");
    end
    
    % Characteristics
    Tlow = 90e-9;
    Eff = 0.8;
    Gm = 120e-6;
    Vref = 0.795;
    Gcs = 10.8; 

    % Function
    %Rload = abs(Vout)/Iload;
    BOOST = (Vin_min < Vout);
    BUCK = (Vin_max >= Vout);

    % Frequency
    Rt = ((100e6/Fsw)-8)/1.2*1000;

    % Ripple
    if (exist('Vpp','var') == 1)
        Cout_boost = 0;
        Cout_buck = 0;
        if (BOOST)
            Cout_boost = Iload_boost/(Fsw*Vpp)*(Vout-Vin_min+Tlow*Fsw*Vin_min)/Vout;
        end
        if (BUCK)
           Cout_buck = (Iload_buck*Tlow)/Vpp; 
        end
        Cout = max(Cout_boost, Cout_buck);
    elseif (exist('Cout','var') == 1)
        if (BOOST)
            Vpp_boost = Iload/(Fsw*Cout)*(Vout-Vin_min+Tlow*Fsw*Vin_min)/Vout;
        end
        if (BUCK)
            Vpp_buck = (Iload*Tlow)/Cout; 
        end
        Vpp = max(Vpp_boost, Vpp_buck);
    end

    % Inductor
    %duty_cycle = (abs(Vout))/(Vin_min+abs(Vout));
    Iind_buck = 0;
    Iind_boost = 0;
    if (BUCK)
        Iind_buck = Iload_boost*Vout/Vin_min/Eff;
    end
    if (BOOST)
        Iind_boost = Iload_buck*Vin_max/Vout/Eff;
    end
    Iind = max(Iind_buck, Iind_boost);
    
    if (exist('Ipp','var') == 1)
        Lsw_buck = 0;
        Lsw_boost = 0;
        if (BUCK)
            Lsw_buck = Vout/Ipp*(Vin_max-Vout)/Vin_max*(1/Fsw-Tlow);
        end
        if (BOOST)
            Lsw_boost = Vin_min/Ipp*(Vout-Vin_min)/Vout*(1/Fsw-Tlow);
        end
        Lsw = max(Lsw_buck, Lsw_boost);
    elseif (exist('Lsw','var') == 1)
        Ipp_buck = 0;
        Ipp_boost = 0;
        if (BUCK)
            Ipp_buck = Vout/Lsw*(Vin_max-Vout)/Vin_max*(1/Fsw-Tlow);
        end
        if (BOOST)
            Ipp_boost = Vin_min/Lsw*(Vout-Vin_min)/Vout*(1/Fsw-Tlow);
        end
        Ipp = max(Ipp_buck, Ipp_boost);
    end
    Isat = Iload+Ipp/2;

    % Output
    Rratio = Vout/Vref-1;

    % Filter
    Rload = Vout/min(Iload);
    if (BOOST)
        Gcs = Gcs*Vin_min/Vout*Eff;
    end
    Fp1 = 1/(2*pi*Rload*Cout);
    Frhpz = Vin_min^2*Rload/(Vout^2*2*pi*Lsw);
    Fcc = Frhpz/6;
    Prhpz = atand(Fcc/Frhpz);
    Gcs = Gcs*Vin_min/Vout*Eff;
    Gout = Gcs*sqrt(Rload^2/((Fcc/Fp1)^2+1));
    Pp1 = atand(Fcc/Fp1);
    Pp2 = 90;
    Pz1 = 50 + Pp1+Pp2+Prhpz -180;
    Gcomp = 1/(Vref/Vout*Gout);
    Rz = Gcomp/Gm;
    Cp1 = tand(Pz1)/(2*pi*Fcc*Rz);
    
    Result = struct("Cout",Cout, "Lsw",Lsw, "Rratio",Rratio, "Rt",Rt, "Rz",Rz, "Cp1",Cp1, "Vpp",Vpp, "Iind",Iind, "Isat",Isat);
end