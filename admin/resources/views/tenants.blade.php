<!doctype html>
<html lang="ja">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>テナント管理</title>
    <style>
        body { font-family: sans-serif; max-width: 64rem; margin: 2rem auto; padding: 0 1rem; line-height: 1.6; }
        input, button { padding: .5rem; } table { width: 100%; border-collapse: collapse; }
        td, th { padding: .6rem; border-bottom: 1px solid #ccc; text-align: left; }
        .warning { background: #fff3cd; padding: 1rem; }
    </style>
</head>
<body>
    <h1>テナント管理（実験用）</h1>
    <p class="warning">作成するのは namespace と基本 NetworkPolicy のみです。アプリ、DB、VM、RBAC、バックアップは作成されません。削除すると namespace 内のリソースも削除されます。外部データは削除されない場合があります。</p>
    @if (session('status')) <p>{{ session('status') }}</p> @endif
    @if ($errors->any()) <p role="alert">{{ $errors->first() }}</p> @endif
    @if (config('platform.writes_enabled'))
        <form method="post" action="{{ route('tenants.store') }}">
            @csrf
            <label>新しいテナント名 <input name="name" placeholder="tenant-example" required maxlength="50"></label>
            <button type="submit">作成</button>
        </form>
    @else
        <p>書き込みは無効です。</p>
    @endif
    <h2>テナント一覧</h2>
    <table>
        <thead><tr><th>namespace</th><th>状態</th><th>管理元</th><th>削除</th></tr></thead>
        <tbody>
        @foreach ($tenants as $tenant)
            @php($name = $tenant['metadata']['name'])
            @php($managed = $tenant['metadata']['labels']['platform.example/managed-by'] ?? 'git/other')
            <tr>
                <td>{{ $name }}</td><td>{{ $tenant['status']['phase'] ?? '不明' }}</td><td>{{ $managed }}</td>
                <td>
                    @if (config('platform.writes_enabled') && $managed === 'admin')
                        <form method="post" action="{{ route('tenants.destroy', $name) }}">
                            @csrf @method('DELETE')
                            <label>確認のため名前を入力 <input name="confirmation" required></label>
                            <button type="submit">削除</button>
                        </form>
                    @endif
                </td>
            </tr>
        @endforeach
        </tbody>
    </table>
</body>
</html>
