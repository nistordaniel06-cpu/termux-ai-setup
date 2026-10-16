#!/usr/bin/env python3
"""One isolated Hermes text task; no gateway, tools or repository writes."""
import contextlib
import io
import os
from pathlib import Path
import sys


def run(env, agent_factory):
    task = env.get("HERMES_TASK", "").strip()
    model = env.get("HERMES_MODEL", "").strip()
    key = env.get("HERMES_API_KEY", "").strip()
    provider = env.get("HERMES_PROVIDER", "groq")
    if provider == "groq" and model == "llama-3.3-70b-versatile":
        model = "openai/gpt-oss-120b"
    if not task or len(task) > 6000:
        raise ValueError("Sarcina trebuie să conțină între 1 și 6000 de caractere.")
    if not model or not key:
        raise ValueError("Configurează secretul HERMES_API_KEY și variabila HERMES_MODEL.")
    if provider not in ("groq", "openrouter"):
        raise ValueError("Furnizor invalid.")
    settings = dict(
        model=model, api_key=key,
        provider="custom" if provider == "groq" else "openrouter",
        base_url="https://api.groq.com/openai/v1" if provider == "groq" else "https://openrouter.ai/api/v1",
        api_mode="chat_completions", enabled_toolsets=[],
        max_iterations=2, max_tokens=1800, run_budget_seconds=120,
        quiet_mode=True, skip_memory=True, skip_context_files=True,
        skip_background_review=True, save_trajectories=False,
        reasoning_config={"enabled": False},
    )
    agent = agent_factory(**settings)
    try:
        # Fail closed if a future Hermes change unexpectedly exposes any tool.
        if agent.tools:
            raise RuntimeError("Rularea text nu permite instrumente.")
        result = agent.run_conversation(
            user_message=task,
            system_message=("Răspunde în română. Pregătești un raport sau o propunere text. "
                            "Nu ai acces la internet, fișiere sau execuție. Nu pretinde că ai "
                            "verificat prețuri, clienți, cod sau date live. Marchează ipotezele. "
                            "Nu inventa rezultate sau încasări."),
        )
        if result.get("error"):
            raise RuntimeError("Furnizorul nu a finalizat cererea.")
        answer = result.get("final_response")
        if not isinstance(answer, str) or not answer.strip():
            raise RuntimeError("Hermes nu a returnat un raport.")
        # Never publish the configured credential even if echoed by a provider.
        return answer.replace(key, "[SECRET REDACTAT]")
    finally:
        agent.close()


def main():
    # Keep upstream diagnostics and provider exceptions out of public run logs.
    try:
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            sys.path.insert(0, os.environ["HERMES_SOURCE"])
            from run_agent import AIAgent
            answer = run(os.environ, AIAgent)
        target = Path(os.environ["HERMES_REPORT_DIR"])
        target.mkdir(parents=True, exist_ok=True)
        (target / "raport.md").write_text(
            "# Raport Hermes\n\nPropunere AI; verifică înainte de utilizare.\n\n" + answer + "\n",
            encoding="utf-8",
        )
        print("Raportul a fost salvat în artifactul hermes-report.")
        return 0
    except Exception:
        print("Rulare nereușită. Verifică furnizorul, modelul, cheia și cota API. Detaliile furnizorului nu sunt publicate.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
