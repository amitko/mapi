function msrv
% Function msrv
% Starts a MATLAB application server
% In conf.mat a configuration structure is placed
% if there is no such file - a default configuration 
% is loaded.
%
% Server processes files placed in the directory 'in' with 
% filename *.in. These files should contain a valid MATLAB 
% code. For each file to be processed, a parallel job is 
% started. While the file is under process it is moved to the
% 'prc' directory. after processing it is moved to 'ok' 
% directory.
%
% A default directory structure is created during the first
% start of the program.
%
% The activity is logged in to a file.
%
% Uses a msrv_call.m for calling a particular request in a new job
%
% There is a usefull Perl interface to this server available at
% http:\\evaluation.nbu.bg

% Dimitar Atanasov, 2009
% datanasov@nbu.bg

    if exist('conf.mat') > 0
        load 'conf.mat';
    else
        CONF.name = 'MATLAB SERVER v1.0';
    end;


    if ~isstruct( CONF )
        error('Missing configuration structure');
    end;

    if ~isfield( CONF, 'home_dir' )
        CONF.home_dir = pwd;
    end;


    if ~isfield( CONF, 'wait' )
        CONF.wait = 3;
    end;

    if ~isfield( CONF, 'log_file' )
        CONF.log_file = 'msrv.log';
    end;

    global F home_dir;

    home_dir = CONF.home_dir;
    F = fopen(CONF.log_file,'a');

    s_log([ CONF.name '------ Start ----- ' ] )

    % Create default directory structure
    check_path (home_dir);
    addpath( home_dir );

    cd (home_dir);
    while CONF.wait

        %get files in working directory /prc
        H = dir([home_dir '/in/*.in']);

         for k = 1:size(H,1)
            f = H(k);
            t = strfind(f.name,'.in');
            f_name = f.name(1:t-1);

            s_log([ ' --- processing ----- ' f_name] );

            movefile(['in/' f.name], ['prc/' f_name '.m']);
            feval(@msrv_call, f_name );

            cd (home_dir);
            movefile(['prc/' f_name '.m'], ['ok/' f.name] );

            s_log([ ' --- processed ----- ' f_name] );
       end;
       pause( CONF.wait );
    end;


% ---------------------------------------------------------
function check_path ( path )
% Check the existing directory structure
% and create default

    if ~isdir( path )
        error 'The Directory does not exists';
    else
        if ~isdir( [path '/output'] )
            mkdir( [path '/output'] );
        end;
        if ~isdir( [path '/prc'] )
            mkdir( [path '/prc'] );
        end;
        if ~isdir( [path '/ok'] )
            mkdir( [path '/ok'] );
        end;
        if ~isdir( [path '/in'] )
            mkdir( [path '/in'] );
        end;
    end;

% ---------------------------------------------------------
function s_log( msg )
% Write messages in Log file
    global F;
    fprintf(F, '%s\n', [sprintf( '%1d-', fix(clock)) ' > ' msg]);