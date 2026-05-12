# Set DOCKER_HOST to the colima socket for Docker-compatible tooling
if command -q colima
    set -l _colima_socket "$HOME/.colima/default/docker.sock"
    if test -S "$_colima_socket"
        set -x DOCKER_HOST "unix://$_colima_socket"
    end
end
