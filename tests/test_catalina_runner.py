"""Run with python3 -m unittest discover -s tests -v; no actual JVM is started."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET


RUNNER = Path(__file__).resolve().parents[1] / 'run-catalina.sh'


class CatalinaRunnerTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='nvim-catalina-test-')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.project = self.base / 'project with spaces'
        self.project.mkdir()
        (self.project / 'pom.xml').touch()
        wrapper = self.project / 'mvnw'
        wrapper.write_text('#!/bin/sh\nmkdir -p target\nprintf WAR > target/example.war\n'
                           'printf "%s\\n" "$@" > build-args.txt\n')
        wrapper.chmod(0o700)
        self.server = self.base / 'server with spaces'
        (self.server / 'bin').mkdir(parents=True)
        (self.server / 'conf').mkdir()
        self.xml = '<Server port="8005"><Service><Connector port="8080" protocol="HTTP/1.1"/>' \
            '<Connector port="8443" protocol="HTTP/1.1" SSLEnabled="true"/>' \
            '<Connector port="8009" protocol="AJP/1.3"/>' \
            '<Engine><Host name="localhost" appBase="webapps"/></Engine></Service></Server>'
        (self.server / 'conf/server.xml').write_text(self.xml)
        catalina = self.server / 'bin/catalina.sh'
        catalina.write_text('''#!/bin/sh
python3 - <<'PY'
import json, os
from pathlib import Path
Path(os.environ['CATALINA_BASE'], 'started.json').write_text(json.dumps({
    name: os.environ[name] for name in ['CATALINA_HOME','CATALINA_BASE','JPDA_ADDRESS','JPDA_SUSPEND']
}))
PY
''')
        catalina.chmod(0o700)
        self.runtime = self.base / 'runtime'

    def run_runner(self, context='/', prepare=False, **changes):
        env = os.environ.copy()
        env.update(NVIM_PROJECT_ROOT=str(self.project), NVIM_SERVER_HOME=str(self.server),
                   NVIM_WAR_FILE='target/example.war', NVIM_SERVER_BASE=str(self.runtime),
                   NVIM_CONTEXT_PATH=context, NVIM_HTTP_PORT='8082', NVIM_DEBUG_PORT='5006')
        env.update(changes)
        return subprocess.run(['bash', str(RUNNER)] + (['--prepare-only'] if prepare else []),
                              env=env, text=True, capture_output=True)

    def test_build_deploy_and_foreground_launch(self):
        result = self.run_runner('/foo/bar')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.runtime / 'webapps/foo#bar.war').read_text(), 'WAR')
        self.assertEqual((self.project / 'build-args.txt').read_text().splitlines(),
                         ['--batch-mode', 'package'])
        started = json.loads((self.runtime / 'started.json').read_text())
        self.assertEqual(started['JPDA_ADDRESS'], '127.0.0.1:5006')
        self.assertEqual(started['CATALINA_HOME'], str(self.server))
        self.assertEqual((self.server / 'conf/server.xml').read_text(), self.xml)

    def test_prepare_does_not_build_or_start(self):
        result = self.run_runner(prepare=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('ROOT.war', result.stdout)
        self.assertFalse((self.project / 'build-args.txt').exists())
        self.assertFalse((self.runtime / 'started.json').exists())
        tree = ET.parse(self.runtime / 'conf/server.xml')
        self.assertEqual(tree.getroot().get('port'), '-1')
        connectors = list(tree.iter('Connector'))
        self.assertEqual(len(connectors), 1)
        self.assertEqual(connectors[0].get('port'), '8082')
        self.assertEqual(connectors[0].get('address'), '127.0.0.1')

    def test_invalid_contexts_and_ports_fail_before_creating_runtime(self):
        for context in ['/../bad', '/foo//bar', 'foo', '/ROOT']:
            with self.subTest(context=context):
                self.assertNotEqual(self.run_runner(context, prepare=True).returncode, 0)
                self.assertFalse(self.runtime.exists())
        for port in ['0', '65536', 'oops', '8082']:
            with self.subTest(port=port):
                self.assertNotEqual(self.run_runner(prepare=True, NVIM_DEBUG_PORT=port).returncode, 0)
                self.assertFalse(self.runtime.exists())

    def test_installation_cannot_be_used_as_runtime(self):
        result = self.run_runner(prepare=True, NVIM_SERVER_BASE=str(self.server))
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.server / 'conf/server.xml').read_text(), self.xml)

    def test_custom_runtime_identity_cannot_silently_change(self):
        self.assertEqual(self.run_runner(prepare=True).returncode, 0)
        result = self.run_runner('/another-app', prepare=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('different settings', result.stderr)

    def test_automatic_bases_distinguish_projects_with_same_name(self):
        state = str(self.base / 'state')
        first = self.run_runner(prepare=True, NVIM_SERVER_BASE='', XDG_STATE_HOME=state)
        self.assertEqual(first.returncode, 0, first.stderr)
        other = self.base / 'another-parent' / self.project.name
        other.mkdir(parents=True)
        (other / 'pom.xml').touch()
        second = self.run_runner(prepare=True, NVIM_SERVER_BASE='', XDG_STATE_HOME=state,
                                 NVIM_PROJECT_ROOT=str(other))
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(len(list((Path(state) / 'nvim/servers').iterdir())), 2)

    def test_lock_prevents_second_launch(self):
        import fcntl
        self.runtime.mkdir()
        with (self.runtime / '.run.lock').open('w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            result = self.run_runner(prepare=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('already running', result.stderr)
            self.assertFalse((self.project / 'build-args.txt').exists())


if __name__ == '__main__':
    unittest.main()
