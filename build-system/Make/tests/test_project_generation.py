import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import ProjectGeneration


class SimulatorProjectGenerationTests(unittest.TestCase):
    def generate(self, disable_profiles):
        with tempfile.TemporaryDirectory() as directory:
            environment = SimpleNamespace(base_path=directory, bazel_path='/mock/bazel')
            with patch.object(ProjectGeneration, 'call_executable') as execute:
                ProjectGeneration.generate_xcodeproj(environment, True, disable_profiles, False, False, [], 'Telegram')
            return execute.call_args.args[0], Path(directory, 'xcodeproj.bazelrc').read_text().splitlines()

    def test_unsigned_simulator_applies_to_generation_and_later_xcode_builds(self):
        command, config = self.generate(True)
        self.assertIn('--//Telegram:disableProvisioningProfiles', command,
                      'project generation must not request a development profile')
        self.assertIn('build --//Telegram:disableProvisioningProfiles', config,
                      'Xcode builds must not request a development profile')

    def test_signed_projects_keep_provisioning_enabled(self):
        command, config = self.generate(False)
        self.assertNotIn('--//Telegram:disableProvisioningProfiles', command)
        self.assertNotIn('build --//Telegram:disableProvisioningProfiles', config)


if __name__ == '__main__':
    unittest.main()
