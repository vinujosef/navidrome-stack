"""Rewrite Ogg Opus tags/artwork using FFmpeg, without encoding audio."""
import base64
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile


def probe(path):
    return json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(path)]))


def picture(data, mime, width, height):
    def number(value):
        return struct.pack('>I', value)
    mime = mime.encode('ascii')
    block = (number(3) + number(len(mime)) + mime + number(0)
             + number(width) + number(height) + number(24) + number(0)
             + number(len(data)) + data)
    return base64.b64encode(block).decode('ascii')


def main():
    source = Path(sys.argv[1])
    args = sys.argv[2:]
    info = probe(source)
    audio = next(s for s in info['streams'] if s['codec_type'] == 'audio')
    if audio['codec_name'] != 'opus':
        raise ValueError('Expected Ogg Opus audio')
    tags = {k.lower(): v for k, v in info.get('format', {}).get('tags', {}).items()}
    tags.update({k.lower(): v for k, v in audio.get('tags', {}).items()})
    cover = None
    while args:
        option, value, *args = args
        if option == '--cover':
            cover = value
        elif option == '-metadata':
            key, value = value.split('=', 1)
            key = key.lower()
            if value:
                tags[key] = value
            else:
                tags.pop(key, None)
        else:
            raise ValueError(f'Unknown argument: {option}')
    image = None
    if cover:
        image = probe(cover)['streams'][0]
        data = Path(cover).read_bytes()
    else:
        image = next((s for s in info['streams']
                      if s.get('disposition', {}).get('attached_pic')), None)
        if image:
            data = subprocess.check_output([
                'ffmpeg', '-v', 'error', '-i', str(source), '-map', f"0:{image['index']}",
                '-frames:v', '1', '-c:v', 'copy', '-f', 'image2pipe', '-'])
    if image:
        mime = {'png': 'image/png', 'mjpeg': 'image/jpeg'}.get(image['codec_name'])
        if not mime:
            raise ValueError('Artwork must be PNG or JPEG')
        tags.pop('coverart', None)
        tags.pop('coverartmime', None)
        tags['metadata_block_picture'] = picture(data, mime, image['width'], image['height'])
    # Pass large embedded pictures through a file, avoiding shell/OS argument limits.
    def escape(value):
        return ''.join('\\' + char if char in '\\;#=\n' else char for char in value)

    with tempfile.TemporaryDirectory(prefix='.opus-metadata.', dir=source.parent) as directory:
        temporary = Path(directory) / 'audio.opus'
        metadata = Path(directory) / 'tags.txt'
        metadata.write_text(';FFMETADATA1\n' + ''.join(
            f'{escape(key)}={escape(value)}\n' for key, value in tags.items()), encoding='utf-8')
        command = ['ffmpeg', '-v', 'error', '-nostdin', '-y', '-i', str(source),
                   '-f', 'ffmetadata', '-i', str(metadata),
                   '-map', '0:a:0', '-c:a', 'copy',
                   '-map_metadata', '-1', '-map_metadata:s:a:0', '1:g']
        subprocess.run(command + [str(temporary)], check=True)
        os.chmod(temporary, source.stat().st_mode & 0o777)
        os.replace(temporary, source)


if __name__ == '__main__':
    main()
