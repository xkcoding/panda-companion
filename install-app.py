"""Development entry point; release users run the bundled native installer."""
import pathlib
import subprocess
root = pathlib.Path(__file__).resolve().parent
subprocess.run([str(root/'build/Install'), str(root/'build/PandaCompanion.app')], check=True)
