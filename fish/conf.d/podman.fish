# Set DOCKER_HOST to the podman socket for Docker-compatible tooling
if command -q podman
    set -l _podman_socket (podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}' 2>/dev/null)
    if test -n "$_podman_socket"
        set -x DOCKER_HOST "unix://$_podman_socket"
    end
end
