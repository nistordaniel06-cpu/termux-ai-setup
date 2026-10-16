import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("report", Path(__file__).parents[1] / "scripts/hermes_actions_report.py")
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)


class ReportTests(unittest.TestCase):
    def setUp(self):
        self.env = dict(HERMES_TASK="Scrie literal $(touch /tmp/should-not-exist)", HERMES_MODEL="test-model", HERMES_API_KEY="test-secret")

    def factory(self, **settings):
        self.settings = settings
        outer = self
        class Agent:
            tools = []
            def run_conversation(self, **kwargs):
                outer.query = kwargs["user_message"]
                return {"final_response": "Rezultat test-secret"}
            def close(self):
                outer.closed = True
        return Agent()

    def test_no_tools_literal_input_and_redaction(self):
        self.assertEqual(report.run(self.env, self.factory), "Rezultat [SECRET REDACTAT]")
        self.assertEqual(self.query, self.env["HERMES_TASK"])
        self.assertEqual(self.settings["enabled_toolsets"], [])
        self.assertTrue(self.settings["skip_background_review"])
        self.assertTrue(self.closed)

    def test_retired_groq_model_uses_supported_replacement(self):
        env = self.env | {
            "HERMES_PROVIDER": "groq",
            "HERMES_MODEL": "llama-3.3-70b-versatile",
        }
        report.run(env, self.factory)
        self.assertEqual(self.settings["model"], "openai/gpt-oss-120b")

    def test_model_is_not_rewritten_for_other_providers(self):
        env = self.env | {
            "HERMES_PROVIDER": "openrouter",
            "HERMES_MODEL": "llama-3.3-70b-versatile",
        }
        report.run(env, self.factory)
        self.assertEqual(self.settings["model"], "llama-3.3-70b-versatile")

    def test_missing_key_and_oversized_input_before_agent_creation(self):
        for patch in ({"HERMES_API_KEY": ""}, {"HERMES_TASK": "x" * 6001}, {"HERMES_PROVIDER": "unknown"}):
            with self.subTest(patch=patch), self.assertRaises(ValueError):
                report.run(self.env | patch, lambda **kw: self.fail("Agent must not start"))

    def test_unexpected_tool_is_blocked_and_agent_closed(self):
        def unsafe_factory(**kwargs):
            agent = self.factory(**kwargs)
            agent.tools = ["terminal"]
            return agent
        with self.assertRaises(RuntimeError):
            report.run(self.env, unsafe_factory)
        self.assertTrue(self.closed)

    def test_provider_error_fails_instead_of_success(self):
        def failing_factory(**kwargs):
            agent = self.factory(**kwargs)
            agent.run_conversation = lambda **kw: {"error": "quota", "final_response": ""}
            return agent
        with self.assertRaises(RuntimeError):
            report.run(self.env, failing_factory)
        self.assertTrue(self.closed)


if __name__ == "__main__":
    unittest.main()
