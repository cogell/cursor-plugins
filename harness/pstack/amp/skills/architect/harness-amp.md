# pstack in Amp

pstack skills use Cursor names. In Amp, read this file once per thread, then map each Cursor name in a skill with the tables below. In Amp each pstack skill stands alone: its folder holds this adapter as `harness-amp.md` and any agent it spawns under `agents/`. The `skill` tool reports a loaded skill's base directory; resolve a skill's relative paths from there. If a Cursor field has no row, drop it and say so. Never pass a field the tool schema rejects.

Amp lists every skill to the model and does not read `disable-model-invocation`, so the Amp tree starts each such skill's description with "Run only when the user names this skill". Load one of those skills only when the user names it or another pstack skill you are following routes to it.

The repository's `AGENTS.md` and the user's instructions win over a pstack step that contradicts them, such as a rule on migrations, on asking before acting, or on how a pull request is opened and reviewed. A pstack skill the user invoked is an explicit request to work its way, so follow its delegation and review steps even where Amp's defaults would do the work in the current thread.

## Tools

| Cursor | Amp |
| --- | --- |
| `Task` | `Task`. Its subagent sees no skill catalog of its own choosing, so name the skill files it must read in the brief. |
| `AskQuestion` | Ask in plain text. Use `ask_user_choice` only when the user asked to be asked questions. |
| Open a todolist | Use a todo tool if the thread has one. Otherwise keep the list in your reply and update it at each phase. |
| Run another pstack skill (`/name` or "the **name** skill") | Load it with the `skill` tool by name. When you tell the user to run it, write "use the `<name>` skill" or `/<name>`. |
| `Grep`, `Glob` | `rg` and `rg --files` through the shell, or `finder` for a search by behavior. |
| A sibling skill at `../<name>/SKILL.md` | Load it with the `skill` tool by name; in Amp each skill is installed alone, so the relative path may not exist. In a `poteto-agent` brief, give the absolute path of the skill you are following and name the other skills to load. |
| `deslop` (`/deslop`) from `cursor-team-kit` | The `emil-unslop-code` skill, if the thread lists it. Otherwise review the diff yourself for narrated comments, dead code, and defensive checks the types already rule out. |
| `control-ui` from `cursor-team-kit` | `agent-browser` through the shell. Run `agent-browser skills get core --full` for its instructions, or load the `using-agent-browser` skill. |
| `control-cli` from `cursor-team-kit` | Drive the CLI or TUI through the shell, using tmux for an interactive one. |
| `create-skill` (`/create-skill`), Cursor's built-in | The `building-skills` skill. |

## Subagent fields

| Cursor | Amp |
| --- | --- |
| `subagent_type: generalPurpose` | `Task` with no extra fields. |
| `poteto-agent`, `comment-sicko` | `Task` whose brief starts: "Read `<base>/agents/<name>.md` and follow it. poteto-mode's SKILL.md is at `<poteto-mode base>/SKILL.md`." `<base>` is the base directory of the skill you are following; load `poteto-mode` with the `skill` tool to learn its base directory. Use absolute paths. |
| `readonly: true` | `finder` for a search, `oracle` for a judgment, or `Task` whose brief says "do not edit files"; check `git status` afterward. |
| `readonly: false` | `Task`. It keeps the thread's MCP servers. |
| `environment: "cloud"` | `create_thread` in an orb. It starts from the default branch with none of this thread's local changes, so push a branch first and name it in the prompt. |
| `environment: "local"` | Omit. |
| `cloud_base_branch: <b>` | Tell the new thread to check out `<b>` first. |
| `run_in_background: true` | `Task` with `mode: "async"`. Its result arrives as a later message; do not poll. |
| `resume` | `Task` with the earlier subagent's `id`. |
| `file_attachments` | List the paths in the brief. |

## Models

Amp's `Task` has no model field: every subagent runs on the thread's model. Another model is reachable two ways, both heavier than a Cursor subagent.

| Cursor | Amp |
| --- | --- |
| A `claude-*`, `grok-*`, or `gpt-*` slug for a code delegate, such as `grok-4.7-xhigh-fast` | `Task`, on the thread's model. Say so in one line. |
| A slug for one lens of a review or judgment panel | Run one lens in `oracle`, a stronger reasoning model, and the rest as `Task` subagents. For a lens that must run on a named family, use `create_thread` with `intent: "independent-review"` and an `agent_mode` from `list_agent_modes` that matches it (for example `grok47-high` for `grok-*`, `gpt56s` for `gpt-*`, `claude-opus-5-5` for `claude-opus-*`), after pushing the branch it reviews. |
| `auto` or `inherit-parent` | `Task`. |
| The `pstack-models.mdc` rule, `~/.cursor/rules/pstack-models.mdc` | `~/.config/amp/pstack-models.md`. Amp does not load it on its own, so read it when a step needs a role's model. If the file or the role's line is missing, use the mapping above for the skill's default slug. |
| A role value | `task`, `oracle`, or an Amp agent mode key, as written by setup-pstack below. |

## setup-pstack

Follow its steps with these changes:

- Detect. List the modes with `list_agent_modes` from the `amp` module, through `tool_search` and `code_exec`. The choices for each role are `task`, `oracle`, and those mode keys. A mode key already fixes its reasoning effort, so the budget step picks a sibling mode, such as `gpt-6-astra-high` over `gpt-6-astra-medium`, where one exists, and otherwise leaves the role as it is.
- Defaults. Code roles default to `task`, judgment and prose roles to `oracle`, and the review panel to `task` plus `oracle`.
- Write. Write `~/.config/amp/pstack-models.md` with no frontmatter, then the comment lines, the `# budget` line, and one line per role. Overwrite the whole file. Never put the role lines in `AGENTS.md`.

## Paths

| Cursor | Amp |
| --- | --- |
| `.cursor/skills/`, `~/.cursor/skills/` | `.agents/skills/`, `~/.config/agents/skills/` |
| `~/.cursor/plugins/`, `.cursor-plugin/plugin.json` | The skill's base directory. Amp has no plugin manifest for skills. |
| `.cursor/rules/*.mdc`, always-applied rules | `AGENTS.md` in the repository. The model rule is the exception. See Models. |
| `https://github.com/cursor/plugins/blob/main/pstack/<path>` | For `skills/<name>/…`, load that skill with the `skill` tool and read the file from its base directory. For anything else, such as `README.md` or `docs/guide/`, read the URL, and give the user the URL when they need a link. |
| Transcripts in `~/.cursor/projects/<slug>/agent-transcripts/` | Amp threads. Find them with `find_thread` from the `amp` module and read one with `read_thread`. They cover the user's threads on every machine, so scope a search to the repository and dates the step names. |

## Cursor-only features

When a step needs a feature Amp lacks, put one line in your reply, `Skipped in Amp: <step>. <reason>.`, then go on to the next step. Do not stop, ask, or retry. When a later step needs what the skipped step made, such as a URL or a key, leave a placeholder and name it in the line.

| Cursor | Amp |
| --- | --- |
| Cursor Automations: routines, `update_state` routine calls, `api2.cursor.sh/automations` webhooks, routine wakes, and `SendToUser` secret requests | Skip with the line. Amp's schedules and plugin webhooks are the nearest equivalent; build one only when the user asks. |
| Bugbot | Bugbot comments on a GitHub PR are ordinary review threads, so triage them with the forge command that the step gives. Skip a step that starts, waits for, or configures Bugbot when the PR has no Bugbot check or comment. |
| Cursor cloud agents | `create_thread` in an orb, as in Subagent fields. Skip a step that needs the cloud agent's own dashboard. |
| A built-in PR tool | Use the forge command that the step gives, such as `gh pr create`. That is not a skip, so write no line. |
| `/loop` and waiting on CI or review | Keep working in the thread. To wait on a pull request, subscribe the thread to its checks and comments with `create_github_subscription` from the `amp` module rather than polling. |
| Custom modes (option+enter) | Amp has none. The user names the skill again, or adds a line to `AGENTS.md`. |
