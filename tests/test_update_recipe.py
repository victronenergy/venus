"""Test recipe manipulation without entering the script's interactive CLI."""

import ast
from pathlib import Path
import tempfile
import unittest


def load_recipe_definitions():
    script = Path(__file__).resolve().parents[1] / 'update-recipe.py'
    tree = ast.parse(script.read_text())
    definitions = []
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id == 'parser' for target in node.targets):
            break
        definitions.append(node)
    namespace = {}
    exec(compile(ast.Module(body=definitions, type_ignores=[]), str(script), 'exec'), namespace)
    return namespace


class RecipeVariableMatchingTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.Recipe = load_recipe_definitions()['Recipe']

    def recipe(self, contents):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        path = Path(tmp.name) / 'demo_1.0.bb'
        path.write_text(contents)
        return self.Recipe(str(path))

    def test_commented_assignment_is_not_updated(self):
        recipe = self.recipe('# SRCREV = "example"\nSRCREV = "live"\n')
        recipe.set_src_rev('new')
        self.assertEqual(recipe._content, '# SRCREV = "example"\nSRCREV = "new"\n')

    def test_identical_text_in_comment_remains_unchanged(self):
        recipe = self.recipe('# SRCREV = "same"\nSRCREV = "same"\n')
        recipe.set_src_rev('new')
        self.assertEqual(recipe._content, '# SRCREV = "same"\nSRCREV = "new"\n')

    def test_other_variable_with_same_suffix_remains_unchanged(self):
        recipe = self.recipe('CUSTOM_SRCREV = "custom"\nSRCREV = "live"\n')
        recipe.set_src_rev('new')
        self.assertEqual(recipe._content, 'CUSTOM_SRCREV = "custom"\nSRCREV = "new"\n')

    def test_comment_only_revision_does_not_hide_missing_variable(self):
        recipe = self.recipe('# SRCREV = "example"\nSRC_URI = "git://example.invalid/demo"\n')
        self.assertFalse(recipe._src_rev.found())
        recipe.set_src_rev('new')
        self.assertEqual(recipe._content,
                         '# SRCREV = "example"\nSRC_URI = "git://example.invalid/demo"\nSRCREV = "new"\n')

    def test_indented_multiline_uri_preserves_formatting(self):
        recipe = self.recipe('# SRC_URI = "example"\n  SRC_URI = "git://example.invalid/old \\\n    file://fix.patch"\n')
        self.assertEqual(recipe._src_uris.words(), ['git://example.invalid/old', 'file://fix.patch'])
        recipe._src_uris.replace('git://example.invalid/old', 'git://example.invalid/new')
        self.assertEqual(recipe._content,
                         '# SRC_URI = "example"\n  SRC_URI = "git://example.invalid/new \\\n    file://fix.patch"\n')

    def test_plain_assignment_can_be_updated_repeatedly_and_saved(self):
        recipe = self.recipe('SRCREV = "old"\n')
        recipe.set_src_rev('first')
        recipe.set_src_rev('second')
        recipe.save()
        self.assertEqual(Path(recipe._bbfile).read_text(), 'SRCREV = "second"\n')

    def test_checksum_variable_matches_literal_brackets(self):
        recipe = self.recipe('# SRC_URI[sha256sum] = "example"\nSRC_URI[sha256sum] = "old"\n')
        recipe._sha256sum.set('new')
        self.assertEqual(recipe._content,
                         '# SRC_URI[sha256sum] = "example"\nSRC_URI[sha256sum] = "new"\n')

    def test_inserting_regex_preserves_backslashes(self):
        recipe = self.recipe('SRC_URI = "git://example.invalid/demo"\n')
        recipe.set_tag_regex(r'v(?P<pver>\d+)')
        self.assertEqual(recipe._content,
                         'UPSTREAM_CHECK_GITTAGREGEX = "v(?P<pver>\\d+)"\nSRC_URI = "git://example.invalid/demo"\n')


if __name__ == '__main__':
    unittest.main()
