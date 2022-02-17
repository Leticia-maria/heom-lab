function [K,c_ts,ts] = constructTC2ABOperator(AB_coupling_info, H_sys_A, H_sys_B,d_heom_A,d_heom_B)

% first we need to generate the correlation functions for each bath
n_baths = numel(AB_coupling_info.baths) ;
cs = [] ;
omegas = [] ;
weights = [] ;
for n = 1:n_baths
    % construct the density of states for the spectral density
    if AB_coupling_info.baths{n}.spectral_density == "debye"
        omega_D = AB_coupling_info.baths{n}.omega_D ;
        lambda_D = AB_coupling_info.baths{n}.lambda_D ;
        rho = @(x)(2.0/pi) * omega_D./(x.*x + omega_D*omega_D) ;
        % discretise the spectral density
        [omegas_bath,weights_bath] = discretiseSpecDenGL(AB_coupling_info.n_modes,rho) ;
        cs_bath = sqrt(2.0*lambda_D *weights_bath).*omegas_bath ;
        omegas  = [omegas , omegas_bath] ;
        cs = [cs , cs_bath] ;
        weights = [weights,weights_bath * lambda_D] ;
    end

end

% calculate the correlation function on the desired time grid
ts = linspace(0,AB_coupling_info.t_max,AB_coupling_info.n_t) ;
c_A_ts = calculateCorrelationFunction(weights,omegas,ts,AB_coupling_info.beta,AB_coupling_info.Delta_E_AB) ;
c_B_ts = calculateCorrelationFunction(weights,omegas,ts,AB_coupling_info.beta,-AB_coupling_info.Delta_E_AB) ;
c_ts = [c_A_ts;c_B_ts] ;
% get dimensions of the system spaces
d_hilb_A = size(H_sys_A,1) ;
d_hilb_B = size(H_sys_B,1) ;
d = d_heom_A + d_heom_B ;
d_liou_A = d_hilb_A^2 ;
d_liou_B = d_hilb_B^2 ;
K = sparse([],[],[],d,d);
id_hilb_A = speye(d_hilb_A) ;
id_hilb_B = speye(d_hilb_B) ;
n_ados = d_heom_A / d_liou_A ;
id_ados = speye(n_ados) ;

% the simplified version simply sets 
if AB_coupling_info.method == "simplified"
    int_c_A = trapz(ts,c_A_ts) ;
    int_c_B = trapz(ts,c_B_ts) ;
    Gamma = AB_coupling_info.coupling_matrix ;
    % construct the AA transfer operator  
    T_AA = -int_c_A * Gamma*(Gamma') ;
    % construct the AA rate superoperator K_AA sigma = T_AA sigma + sigma T_AA^dag
    K_AA_liou = kron(T_AA,id_hilb_A) + kron(id_hilb_A,conj(T_AA)) ;
    K(1:d_heom_A,1:d_heom_A) = kron(id_ados,K_AA_liou) ;

    % construct T_BB
    T_BB = -int_c_B * ((Gamma')*(Gamma)) ;
    K_BB_liou = kron(T_BB,id_hilb_B) + kron(id_hilb_B,conj(T_BB)) ;
    K((d_heom_A+1):(d_heom_A+d_heom_B),(d_heom_A+1):(d_heom_A+d_heom_B)) = kron(id_ados,K_BB_liou) ;

    % construct the B<-A term
    K_BA_liou = (int_c_A + conj(int_c_A))*kron(Gamma',transpose(Gamma)) ;
    K((d_heom_A+1):(d_heom_A+d_heom_B),1:d_heom_A) = kron(id_ados,K_BA_liou) ;
    % construct the A<-B term
    K_AB_liou = (int_c_B + conj(int_c_B))*kron(Gamma,conj(Gamma)) ;
    K(1:d_heom_A,(d_heom_A+1):(d_heom_A+d_heom_B)) = kron(id_ados,K_AB_liou) ;
elseif AB_coupling_info.method == "include H_sys"
    % calculate the eigenstates of the system Hamiltonians
    [psi_As,E_As] = eig(H_sys_A,'vector') ;
    [psi_Bs,E_Bs] = eig(H_sys_B,'vector') ;


    % calculate the coupling matrix in the system energy eigenbasis
    Gamma_E = psi_As' * AB_coupling_info.coupling_matrix * psi_Bs ;
    Delta_E_AB_sys = E_Bs - E_As' ;

    G = zeros(d_hilb_B,d_hilb_A) ;
    for n_A = 1:d_hilb_A
        for n_B = 1:d_hilb_B
            G(n_B,n_A) = trapz(ts,c_ts.*exp(-0.0i*(E_Bs(n_B)-E_As(n_A))*ts)) ;
        end
    end
    T_AA_E = Gamma_E * (G .* Gamma_E') ;
    T_AA = psi_As*T_AA_E*(psi_As')  ;
end




end