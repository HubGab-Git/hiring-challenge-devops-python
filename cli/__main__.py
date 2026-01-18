import argparse
import json
import os
import sys

import requests


API_URL = os.getenv("API_URL", "http://localhost:8000")


def request(method: str, path: str, payload=None):
    url = f"{API_URL}{path}"
    resp = requests.request(method, url, json=payload, timeout=10)
    if resp.status_code >= 400:
        print(resp.text)
        sys.exit(1)
    if resp.status_code == 204:
        return None
    return resp.json()


def cmd_list(_args):
    data = request("GET", "/servers")
    print(json.dumps(data, indent=2))


def cmd_get(args):
    data = request("GET", f"/servers/{args.id}")
    print(json.dumps(data, indent=2))


def cmd_create(args):
    payload = {
        "hostname": args.hostname,
        "ip_address": args.ip,
        "state": args.state,
    }
    data = request("POST", "/servers", payload)
    print(json.dumps(data, indent=2))


def cmd_update(args):
    payload = {
        "hostname": args.hostname,
        "ip_address": args.ip,
        "state": args.state,
    }
    data = request("PUT", f"/servers/{args.id}", payload)
    print(json.dumps(data, indent=2))


def cmd_delete(args):
    request("DELETE", f"/servers/{args.id}")
    print("deleted")


def build_parser():
    parser = argparse.ArgumentParser(description="Inventory CLI")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("list", help="List servers").set_defaults(func=cmd_list)

    get_p = sub.add_parser("get", help="Get server")
    get_p.add_argument("id", type=int)
    get_p.set_defaults(func=cmd_get)

    create_p = sub.add_parser("create", help="Create server")
    create_p.add_argument("hostname")
    create_p.add_argument("ip")
    create_p.add_argument("state", choices=["active", "offline", "retired"])
    create_p.set_defaults(func=cmd_create)

    update_p = sub.add_parser("update", help="Update server")
    update_p.add_argument("id", type=int)
    update_p.add_argument("hostname")
    update_p.add_argument("ip")
    update_p.add_argument("state", choices=["active", "offline", "retired"])
    update_p.set_defaults(func=cmd_update)

    delete_p = sub.add_parser("delete", help="Delete server")
    delete_p.add_argument("id", type=int)
    delete_p.set_defaults(func=cmd_delete)

    return parser


def main():
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
