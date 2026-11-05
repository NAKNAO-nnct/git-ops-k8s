<?php

namespace Tests\Feature;

use App\Services\KubernetesTenants;
use Mockery;
use Tests\TestCase;

class TenantSecurityTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config([
            'platform.username' => 'operator',
            'platform.password_hash' => password_hash('correct-password', PASSWORD_BCRYPT),
            'platform.writes_enabled' => false,
        ]);
    }

    public function test_credentials_are_required(): void
    {
        $this->get('/')->assertUnauthorized();
        $this->withBasicAuth('operator', 'wrong')->get('/')->assertUnauthorized();
    }

    public function test_missing_auth_configuration_fails_closed(): void
    {
        config(['platform.password_hash' => null]);
        $this->get('/')->assertStatus(503);
    }

    public function test_writes_are_disabled_by_default(): void
    {
        $this->withBasicAuth('operator', 'correct-password')
            ->post('/tenants', ['name' => 'tenant-test'])->assertForbidden();
        $this->withBasicAuth('operator', 'correct-password')
            ->delete('/tenants/tenant-test', ['confirmation' => 'tenant-test'])->assertForbidden();
    }

    public function test_tenant_name_is_validated(): void
    {
        config(['platform.writes_enabled' => true]);
        $this->withBasicAuth('operator', 'correct-password')
            ->post('/tenants', ['name' => 'kube-system'])->assertSessionHasErrors('name');
    }

    public function test_creation_calls_tenant_service_when_enabled(): void
    {
        config(['platform.writes_enabled' => true]);
        $service = Mockery::mock(KubernetesTenants::class);
        $service->shouldReceive('create')->once()->with('tenant-example');
        $this->app->instance(KubernetesTenants::class, $service);

        $this->withBasicAuth('operator', 'correct-password')
            ->post('/tenants', ['name' => 'tenant-example'])->assertRedirect('/');
    }

    public function test_delete_checks_confirmation_before_calling_service(): void
    {
        config(['platform.writes_enabled' => true]);
        $service = Mockery::mock(KubernetesTenants::class);
        $service->shouldNotReceive('delete');
        $this->app->instance(KubernetesTenants::class, $service);

        $this->withBasicAuth('operator', 'correct-password')
            ->delete('/tenants/tenant-example', ['confirmation' => 'wrong'])
            ->assertSessionHasErrors('confirmation');
    }
}
