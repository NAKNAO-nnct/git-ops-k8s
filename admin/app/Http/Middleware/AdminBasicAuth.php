<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AdminBasicAuth
{
    public function handle(Request $request, Closure $next): Response
    {
        $username = config('platform.username');
        $hash = config('platform.password_hash');
        if (! is_string($username) || $username === '' || ! is_string($hash) || $hash === '') {
            abort(503, '管理画面の認証が設定されていません。');
        }

        $providedUser = $request->getUser() ?? '';
        $providedPassword = $request->getPassword() ?? '';
        if (! hash_equals($username, $providedUser) || ! password_verify($providedPassword, $hash)) {
            return response('Authentication required', 401, ['WWW-Authenticate' => 'Basic realm="Tenant admin"']);
        }

        return $next($request);
    }
}
