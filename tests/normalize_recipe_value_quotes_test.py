from pathlib import Path
import ast
import re
import unittest
SCRIPT = Path(__file__).resolve().parents[1] / 'update-recipe.py'
tree = ast.parse(SCRIPT.read_text())
# Load the real helper class without running the command-line parser.
classes = [node for node in tree.body
           if isinstance(node, ast.ClassDef) and node.name == 'BitbakeVarDef']
namespace = {'re': re, 'warn': lambda *args: None}
exec(compile(ast.Module(body=classes, type_ignores=[]), str(SCRIPT), 'exec'), namespace)
VarDef = namespace['BitbakeVarDef']

class RecipeQuoteTest(unittest.TestCase):
    def test_embedded_quotes_are_normalized(self):
        expected = 'DESCRIPTION = ' + chr(34) + "a 'quoted' word" + chr(34)
        self.assertEqual(VarDef.var_def('DESCRIPTION', 'a "quoted" word'), expected)
        self.assertEqual(VarDef.var_def('PV', '1.2'), 'PV = "1.2"')
