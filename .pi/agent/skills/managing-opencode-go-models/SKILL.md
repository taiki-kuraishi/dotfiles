---
name: managing-opencode-go-models
description: Use when temporarily adding a newly released OpenCode Go model to Pi or removing temporary entries after Pi catches up or OpenCode Go retires them.
disable-model-invocation: true
---

# OpenCode Go モデル管理

Pi カタログの遅延だけを `~/.pi/agent/models.json` で埋める。引数ありなら指定した
1モデルの追加も検討し、引数なしなら整理だけ行う。

## 境界

- `providers.opencode-go.models` の全要素をこの Skill の管理対象とする。
- `modelOverrides` と他 provider は変更しない。
- VCS 操作前に `~/.pi/agent/skills/yadm-dotfiles/SKILL.md` を読み、plain `git` は使わない。
- stage / commit / push は user の明示指示を待つ。

## 1. 在庫を更新する

変更前の `yadm status` / `yadm diff` を記録してから、次の3集合を取得する。

1. `pi update --models` 後の `~/.pi/agent/models-store.json` にある
   `opencode-go.models[].id`（Pi カタログ）。
2. `GET https://opencode.ai/zen/go/v1/models` の `data[].id`（現在提供中）。
3. `models.json` の `providers.opencode-go.models`（一時登録）。

`models-store.json` は Pi カタログであり、OpenCode Go のライブ一覧ではない。手編集しない。

## 2. 整理と追加を判定する

| 条件 | 一時登録の扱い |
| --- | --- |
| ID が Pi カタログにある | 削除候補。Pi 側の定義へ戻す |
| ID がライブ一覧にない | 削除候補。提供終了 |
| ライブにあり、Pi カタログにない | 維持 |

引数のモデルは ID をライブ一覧で確定する。Pi カタログ収録済みなら追加しない。ライブ一覧に
無ければ追加しない。残る場合だけ §3 へ進む。

## 3. metadata gate

以下を公式 OpenCode Go docs、`anomalyco/models.dev` の
`providers/opencode-go/models/<id>.toml`、必要なら `models.dev/api.json` で確定する。

- `id`, `name`, endpoint/API type, input modality
- input/output/cache cost, context limit, output limit
- `reasoning_options`

endpoint は Pi へ次のように写す。

| OpenCode Go endpoint | `api` | `baseUrl` |
| --- | --- | --- |
| `/v1/responses` | `openai-responses` | `https://opencode.ai/zen/go/v1` |
| `/v1/chat/completions` | `openai-completions` | `https://opencode.ai/zen/go/v1` |
| `/v1/messages` | `anthropic-messages` | `https://opencode.ai/zen/go` |

source は次の Pi field へ exact に変換する。

| models.dev source | Pi model field |
| --- | --- |
| `attachment = true/false` | `input: ["text", "image"]` / `["text"]` |
| `cost.input/output/cache_read/cache_write` | `cost.input/output/cacheRead/cacheWrite`（欠損を推測せず、公式の free/unsupported または normalized 値で `0` を確定） |
| `limit.context` | `contextWindow` |
| `limit.output` | `maxTokens` |

追加結果は models.dev object ではなく、次の順の **Pi model object** とする:
`id`, `name`, `api`, `baseUrl`, `reasoning`, 必要時だけ `thinkingLevelMap`, `input`,
`cost { input, output, cacheRead, cacheWrite }`, `contextWindow`, `maxTokens`, 証拠がある場合だけ
`compat`。`contextLimit`, `provider.npm`, release date, description など他の field は含めない。

### Effort

- `reasoning_options = []`: always-on だが request-time control なし。
  Pi には `reasoning: false` とし、`thinkingLevelMap` / thinking `compat` を付けない。
- `type = "effort"`: `reasoning: true`。7つの Pi level をすべて書き、公式 values と同名の
  level は**必ずその文字列**、未対応 level は `null` にする。`none` だけは `off` へ写す。
  例: values が `["low", "high", "max"]` なら次の exact map になる。

  ```json
  {
    "off": null,
    "minimal": null,
    "low": "low",
    "medium": null,
    "high": "high",
    "xhigh": null,
    "max": "max"
  }
  ```

  `max` を含むなら `"max": "max"` であり、`null` ではない。
- `toggle`, `budget_tokens`, 複数 option、特殊な transport: 現行 Pi docs/source と OpenCode の
  request transform で exact payload を確認してから設定する。安全な写像を証明できなければ追加しない。

必須 metadata が1つでも無ければ停止し、不足項目を報告する。期限、管理者の仮値許可、
「smoke test で後から直す」は推測値を入れる根拠にならない。

## 4. 変更する

追加・削除候補、metadata の出典、effort 写像、exact diff をまとめ、user に1回確認する。
承認後、`models` 配列だけを編集する。空になった配列キーは消すが、`modelOverrides` が残る
provider は残す。空 provider は消す。

## 5. 検証する

```bash
python3 -m json.tool ~/.pi/agent/models.json >/dev/null
pi --list-models
yadm diff --check
yadm status --short
```

対象 ID の重複がなく、追加・維持・削除の判断どおりで、開始時からの別差分が混ざって
いないことを確認する。実推論は user が求めた場合だけ行う。

## よくある間違い

| 思考 | 現実 |
| --- | --- |
| `/v1/models` だけで登録できる | ID しか得られない。metadata gate が別途必要 |
| `reasoning = true` なら Pi も `true` | request-time control が無ければ Pi は `false` |
| 多数派の API と控えめな limit なら安全 | 推測した transport/limit はモデルを壊す |
| Pi カタログに入った一時定義を残す | custom entry が新しい公式 metadata を上書きし続ける |
