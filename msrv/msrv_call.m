function msrv_call( f )
% Function msrv_call
% Part of vsrv.
% Used from msrv to call a specific script 
% placed in prc

% Dimitar Atanasov, 2009
% datanasov@nbu.bg

cd ('prc');
job = batch( f );
