import argparse
import json
import logging
from pathlib import Path

import jsonmerge


def override_json(base_json: dict, override_json: dict) -> dict:
    # by default will override keys or add new ones and won't delete keys from the base
    # see tests for check the behavior
    return jsonmerge.merge(base_json, override_json)


def get_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description='Andromeda config merger')

    parser.add_argument('-b', '--base', required=True, type=Path, help='Full path for the base json')
    parser.add_argument('-p', '--patch', required=True, type=Path, help='Full path for the patch json')
    parser.add_argument('-o', '--output', required=True, type=Path, help='Full path for the output json')

    return parser.parse_args()


def get_json_content(full_path: Path) -> dict:
    with open(full_path.resolve(), "r") as f:
        return json.load(f)


if __name__ == '__main__':
    try:
        args = get_args()
        logging.info(f"Parsed args: f{vars(args)}")
        base_content = get_json_content(args.base)
        patch_content = get_json_content(args.patch)
        patched = override_json(base_content, patch_content)
        logging.info(f"Patched version: ${patched}")
        with open(args.output.resolve(), "w") as f:
            json.dump(patched, f, indent=4)
        logging.info("Finished to merge jsons")
    except Exception as e:
        logging.error(f"Failed to run script with {e}")
        raise