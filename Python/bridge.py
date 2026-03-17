import asyncio
import json
import os
import sys
from pathlib import Path

from pylitterbot import Account
from pylitterbot.robot.feederrobot import FeederRobot


def token_cache_path() -> Path:
    return Path(os.environ["WHISKERS_TOKEN_CACHE"])


def load_tokens() -> dict | None:
    path = token_cache_path()
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text())
    except Exception:
        return None


def save_tokens(tokens: dict | None) -> None:
    if not tokens:
        return
    path = token_cache_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(tokens))


def feeder_to_dict(robot: FeederRobot) -> dict:
    return {
        "serial": robot.serial,
        "name": robot.name,
    }


async def connect_account() -> Account:
    account = Account(token=load_tokens(), token_update_callback=save_tokens)
    await account.connect(
        username=os.environ["WHISKERS_EMAIL"],
        password=os.environ["WHISKERS_PASSWORD"],
        load_robots=True,
    )
    return account


def choose_feeder(account: Account) -> FeederRobot:
    feeders = [robot for robot in account.robots if isinstance(robot, FeederRobot)]
    if not feeders:
        raise RuntimeError("No Feeder-Robot devices were found for this account.")

    serial = os.environ.get("WHISKERS_FEEDER_SERIAL", "").strip()
    if serial:
        for feeder in feeders:
            if feeder.serial == serial:
                return feeder
        raise RuntimeError(f"Selected feeder serial not found: {serial}")

    if len(feeders) != 1:
        raise RuntimeError("Multiple feeders found. Select one in the app first.")
    return feeders[0]


async def list_feeders() -> None:
    account = await connect_account()
    try:
        feeders = [robot for robot in account.robots if isinstance(robot, FeederRobot)]
        print(json.dumps([feeder_to_dict(feeder) for feeder in feeders]))
    finally:
        await account.disconnect()


async def give_snack() -> None:
    account = await connect_account()
    try:
        feeder = choose_feeder(account)
        ok = await feeder.give_snack()
        payload = {
            "ok": ok,
            "message": f"Snack sent to {feeder.name}" if ok else f"Whisker rejected the snack command for {feeder.name}",
            "feederName": feeder.name,
            "timestamp": __import__("datetime").datetime.now(__import__("datetime").timezone.utc).isoformat().replace("+00:00", "Z"),
        }
        print(json.dumps(payload))
    finally:
        await account.disconnect()


async def main() -> None:
    command = sys.argv[1]
    if command == "list-feeders":
        await list_feeders()
    elif command == "give-snack":
        await give_snack()
    else:
        raise RuntimeError(f"Unknown command: {command}")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise
