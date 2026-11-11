#!/usr/bin/env python3
"""Initialize only the disposable servers in this Compose project."""
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

# SOURCE_HOST: the machine running compose.yaml, as clients reach it.
HOST = os.environ.get('SOURCE_HOST', '127.0.0.1')
JELLYFIN = f'http://{HOST}:18096'
PLEX = f'http://{HOST}:13240'
EMBY = f'http://{HOST}:18097/emby'
AUTH = 'MediaBrowser Client="OpenPlayX Test", Device="Integration", DeviceId="openplayx-test", Version="1"'


def call(base, path, method='GET', body=None, headers=None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(base + path, data=data, method=method,
        headers={'Content-Type': 'application/json', **(headers or {})})
    try:
        response = urllib.request.urlopen(req, timeout=10)
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors='replace')
        raise RuntimeError(f'{method} {path.split("?")[0]}: HTTP {error.code}: {detail[:1000]}') from None
    with response:
        payload = response.read()
        if not payload:
            return None
        return json.loads(payload)


def wait(base, path):
    for _ in range(60):
        try:
            return call(base, path)
        except (OSError, ValueError):
            time.sleep(1)
    raise RuntimeError(f'Service did not become ready: {base}')


def setup_emby():
    headers = {'X-Emby-Authorization': AUTH}
    wait(EMBY, '/System/Info/Public')
    try:
        call(EMBY, '/Startup/Configuration', 'POST',
            {'UICulture': 'en-US', 'MetadataCountryCode': 'US', 'PreferredMetadataLanguage': 'en'})
        call(EMBY, '/Startup/User')
        call(EMBY, '/Startup/User', 'POST', {'Name': 'openplayx', 'Password': 'test-only-password'})
        call(EMBY, '/Startup/Complete', 'POST')
    except RuntimeError:
        pass  # The wizard already ran on this container.
    auth = call(EMBY, '/Users/AuthenticateByName', 'POST',
        {'Username': 'openplayx', 'Pw': 'test-only-password'}, headers)
    token = auth['AccessToken']
    user = auth['User']['Id']
    headers = {'X-Emby-Authorization': AUTH + ', Token="' + token + '"', 'X-Emby-Token': token}
    if not call(EMBY, '/Library/VirtualFolders', headers=headers):
        query = urllib.parse.urlencode({'name': 'Test Videos', 'collectionType': 'homevideos',
            'paths': '/media', 'refreshLibrary': 'true'})
        call(EMBY, '/Library/VirtualFolders?' + query, 'POST',
            {'LibraryOptions': {'PathInfos': [{'Path': '/media'}], 'EnableRealtimeMonitor': False}}, headers)
    call(EMBY, '/Library/Refresh', 'POST', headers=headers)
    for _ in range(90):
        items = call(EMBY, f'/Users/{user}/Items?Recursive=true&IncludeItemTypes=Video,Movie', headers=headers)
        if items.get('Items'):
            return user, token
        time.sleep(1)
    raise RuntimeError('Emby media scan timed out')


def main():
    info = wait(JELLYFIN, '/System/Info/Public')
    if not info['StartupWizardCompleted']:
        call(JELLYFIN, '/Startup/Configuration', 'POST',
            {'UICulture': 'en-US', 'MetadataCountryCode': 'US', 'PreferredMetadataLanguage': 'en'})
        call(JELLYFIN, '/Startup/User')  # Creates the first user on a fresh server.
        call(JELLYFIN, '/Startup/User', 'POST', {'Name': 'openplayx', 'Password': 'test-only-password'})
        call(JELLYFIN, '/Startup/RemoteAccess', 'POST', {'EnableRemoteAccess': True, 'EnableAutomaticPortMapping': False})
        call(JELLYFIN, '/Startup/Complete', 'POST')
    auth = call(JELLYFIN, '/Users/AuthenticateByName', 'POST',
        {'Username': 'openplayx', 'Pw': 'test-only-password'}, {'Authorization': AUTH})
    token = auth['AccessToken']
    headers = {'Authorization': AUTH + ', Token="' + token + '"'}
    libraries = call(JELLYFIN, '/Library/VirtualFolders', headers=headers)
    if not libraries:
        call(JELLYFIN, '/Library/VirtualFolders?name=Test%20Videos&collectionType=homevideos&refreshLibrary=true', 'POST',
            {'LibraryOptions': {'PathInfos': [{'Path': '/media'}], 'EnableRealtimeMonitor': False,
                                'EnableInternetProviders': False, 'EnableAutomaticSeriesGrouping': False}}, headers)
    call(JELLYFIN, '/Library/Refresh', 'POST', headers=headers)
    for _ in range(60):
        items = call(JELLYFIN, f'/Users/{auth["User"]["Id"]}/Items?Recursive=true&IncludeItemTypes=Video,Movie', headers=headers)
        if items.get('Items'):
            break
        time.sleep(1)
    else:
        raise RuntimeError('Jellyfin media scan timed out')

    for _ in range(60):
        try:
            sections = call(PLEX, '/library/sections', headers={'Accept': 'application/json'})
            break
        except (OSError, ValueError):
            time.sleep(1)
    else:
        raise RuntimeError('Plex did not become ready')
    if not sections['MediaContainer'].get('Directory'):
        query = urllib.parse.urlencode({'name': 'Test Videos', 'type': 'movie',
            'agent': 'com.plexapp.agents.none', 'scanner': 'Plex Video Files Scanner',
            'language': 'xn', 'location': '/media'})
        call(PLEX, '/library/sections?' + query, 'POST', headers={'Accept': 'application/json'})
    sections = call(PLEX, '/library/sections', headers={'Accept': 'application/json'})
    section = sections['MediaContainer']['Directory'][0]['key']
    # refresh returns no JSON (usually HTTP 200 with an empty body).
    call(PLEX, f'/library/sections/{section}/refresh', headers={'Accept': 'application/json'})
    for _ in range(60):
        items = call(PLEX, f'/library/sections/{section}/all', headers={'Accept': 'application/json'})
        if items['MediaContainer'].get('Metadata'):
            break
        time.sleep(1)
    else:
        raise RuntimeError('Plex media scan timed out')
    emby_user, emby_token = setup_emby()
    defines = {'SOURCE_SERVICES': True, 'SOURCE_HOST': HOST,
               'JELLYFIN_USER_ID': auth['User']['Id'], 'JELLYFIN_TOKEN': token,
               'EMBY_USER_ID': emby_user, 'EMBY_TOKEN': emby_token}
    output = Path(__file__).with_name('defines.local.json')
    output.write_text(json.dumps(defines))
    output.chmod(0o600)
    print('Disposable source services are ready. Test defines written to ' + str(output))


if __name__ == '__main__':
    main()
