<?php

namespace App\Http\Controllers;

use App\Services\KubernetesTenants;
use Illuminate\Http\Client\RequestException;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\View\View;

class TenantController extends Controller
{
    public function index(KubernetesTenants $tenants): View
    {
        return view('tenants', ['tenants' => $tenants->list()]);
    }

    public function store(Request $request, KubernetesTenants $tenants): RedirectResponse
    {
        abort_unless(config('platform.writes_enabled'), 403, '書き込みは無効です。');
        $data = $request->validate([
            'name' => ['required', 'string', 'max:50', 'regex:/\Atenant-[a-z0-9]+(?:-[a-z0-9]+)*\z/'],
        ]);
        try {
            $tenants->create($data['name']);
        } catch (RequestException $exception) {
            Log::error('Tenant creation failed', ['tenant' => $data['name'], 'status' => $exception->response->status()]);

            return back()->withErrors(['name' => '作成に失敗しました。namespace が途中まで作成されている可能性があるため、管理者が確認してください。']);
        }

        return redirect()->route('tenants.index')->with('status', 'namespace と基本ポリシーを作成しました。アプリと DB は別途配置してください。');
    }

    public function destroy(Request $request, KubernetesTenants $tenants, string $name): RedirectResponse
    {
        abort_unless(config('platform.writes_enabled'), 403, '書き込みは無効です。');
        abort_unless(preg_match('/\Atenant-[a-z0-9]+(?:-[a-z0-9]+)*\z/', $name), 404);
        $request->validate(['confirmation' => ['required', 'string', 'in:'.$name]]);
        abort_unless($tenants->delete($name), 403, 'この画面で作成したテナント以外は削除できません。');

        return redirect()->route('tenants.index')->with('status', 'namespace の削除を要求しました。');
    }
}
