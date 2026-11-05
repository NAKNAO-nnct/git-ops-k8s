<?php

namespace App\Services;

use Illuminate\Http\Client\PendingRequest;
use Illuminate\Support\Facades\Http;

class KubernetesTenants
{
    protected function client(): PendingRequest
    {
        $host = getenv('KUBERNETES_SERVICE_HOST');
        $port = getenv('KUBERNETES_SERVICE_PORT_HTTPS') ?: '443';
        $dir = '/var/run/secrets/kubernetes.io/serviceaccount';
        if (! $host || ! is_readable("$dir/token") || ! is_readable("$dir/ca.crt")) {
            throw new \RuntimeException('Kubernetes service account is unavailable');
        }

        $token = file_get_contents("$dir/token");
        if ($token === false || $token === '') {
            throw new \RuntimeException('Kubernetes service account token is unreadable');
        }

        return Http::baseUrl("https://{$host}:{$port}")
            ->withToken(trim($token))
            ->acceptJson()
            ->asJson()
            ->withOptions(['verify' => "$dir/ca.crt"])
            ->timeout(10);
    }

    public function list(): array
    {
        return $this->client()->get('/api/v1/namespaces', [
            'labelSelector' => 'platform.example/tenant',
        ])->throw()->json('items');
    }

    public function create(string $name): void
    {
        $client = $this->client();
        $client->post('/api/v1/namespaces', [
            'apiVersion' => 'v1',
            'kind' => 'Namespace',
            'metadata' => [
                'name' => $name,
                'labels' => ['platform.example/tenant' => $name, 'platform.example/managed-by' => 'admin'],
            ],
        ])->throw();

        $policyPath = "/apis/networking.k8s.io/v1/namespaces/{$name}/networkpolicies";
        $client->post($policyPath, [
            'apiVersion' => 'networking.k8s.io/v1',
            'kind' => 'NetworkPolicy',
            'metadata' => ['name' => 'default-deny'],
            'spec' => ['podSelector' => (object) [], 'policyTypes' => ['Ingress', 'Egress']],
        ])->throw();
        $client->post($policyPath, [
            'apiVersion' => 'networking.k8s.io/v1',
            'kind' => 'NetworkPolicy',
            'metadata' => ['name' => 'same-tenant-and-dns'],
            'spec' => [
                'podSelector' => (object) [],
                'policyTypes' => ['Ingress', 'Egress'],
                'ingress' => [['from' => [['podSelector' => (object) []]]]],
                'egress' => [
                    ['to' => [['podSelector' => (object) []]]],
                    [
                        'to' => [[
                            'namespaceSelector' => ['matchLabels' => ['kubernetes.io/metadata.name' => 'kube-system']],
                            'podSelector' => ['matchLabels' => ['k8s-app' => 'kube-dns']],
                        ]],
                        'ports' => [['protocol' => 'UDP', 'port' => 53], ['protocol' => 'TCP', 'port' => 53]],
                    ],
                ],
            ],
        ])->throw();
    }

    public function delete(string $name): bool
    {
        $client = $this->client();
        $namespace = $client->get("/api/v1/namespaces/{$name}")->throw()->json();
        if (($namespace['metadata']['labels']['platform.example/managed-by'] ?? null) !== 'admin'
            || ($namespace['metadata']['labels']['platform.example/tenant'] ?? null) !== $name) {
            return false;
        }
        $client->send('DELETE', "/api/v1/namespaces/{$name}", [
            'json' => ['apiVersion' => 'v1', 'kind' => 'DeleteOptions', 'preconditions' => [
                'uid' => $namespace['metadata']['uid'],
                'resourceVersion' => $namespace['metadata']['resourceVersion'],
            ]],
        ])->throw();

        return true;
    }
}
