<?php

namespace Tests\Feature;

use App\Services\KubernetesTenants;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Http\Client\Request;
use Illuminate\Http\Client\RequestException;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class KubernetesTenantsTest extends TestCase
{
    private function service(): KubernetesTenants
    {
        return new class extends KubernetesTenants
        {
            protected function client(): PendingRequest
            {
                return Http::baseUrl('https://kubernetes.test')->asJson();
            }
        };
    }

    public function test_create_submits_namespace_and_both_policies(): void
    {
        Http::fake(['*' => Http::response([], 201)]);

        $this->service()->create('tenant-example');

        Http::assertSentCount(3);
        Http::assertSent(fn (Request $request) => $request->url() === 'https://kubernetes.test/api/v1/namespaces'
            && $request['metadata']['labels']['platform.example/managed-by'] === 'admin');
        Http::assertSent(fn (Request $request) => ($request['metadata']['name'] ?? null) === 'default-deny'
            && $request['spec']['policyTypes'] === ['Ingress', 'Egress']);
        Http::assertSent(fn (Request $request) => ($request['metadata']['name'] ?? null) === 'same-tenant-and-dns'
            && $request['spec']['egress'][1]['ports'][0]['port'] === 53);
    }

    public function test_delete_refuses_unmanaged_namespace(): void
    {
        Http::fake(['*' => Http::response(['metadata' => ['labels' => ['platform.example/tenant' => 'tenant-a']]], 200)]);

        $this->assertFalse($this->service()->delete('tenant-a'));
        Http::assertSentCount(1);
    }

    public function test_create_reports_policy_failure(): void
    {
        Http::fakeSequence()->push([], 201)->push(['message' => 'forbidden'], 403);
        $this->expectException(RequestException::class);
        $this->service()->create('tenant-example');
    }

    public function test_delete_uses_uid_and_resource_version_preconditions(): void
    {
        Http::fake(function (Request $request) {
            return $request->method() === 'GET'
                ? Http::response(['metadata' => [
                    'labels' => ['platform.example/tenant' => 'tenant-x', 'platform.example/managed-by' => 'admin'],
                    'uid' => 'uid-1',
                    'resourceVersion' => '42',
                ]], 200)
                : Http::response([], 202);
        });

        $this->assertTrue($this->service()->delete('tenant-x'));
        Http::assertSentCount(2);
        Http::assertSent(fn (Request $request) => $request->method() === 'DELETE'
            && $request['preconditions']['uid'] === 'uid-1'
            && $request['preconditions']['resourceVersion'] === '42');
    }
}
