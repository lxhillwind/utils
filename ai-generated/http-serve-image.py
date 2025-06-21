#!/usr/bin/env python3

import os
import re
from flask import Flask, render_template_string, send_from_directory

current_path = os.getcwd()

if os.getcwd() == os.getenv('HOME'):
    raise Exception('PWD is HOME, exiting...')

app = Flask(__name__)

index_template = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Image Preview</title>
    <style>
        img {
            max-width: 70%;  /* 默认显示宽度，适用于电脑等大屏幕设备 */
            height: auto;
        }

        @media only screen and (max-width: 600px) {
            /* 如果屏幕宽度小于等于 600px，适用于手机等小屏幕设备 */
            img {
                max-width: 100%;
            }
        }
    </style>
</head>
<body>
    <h1>Current Path: {{ current_path }}</h1>
    
    {% if images_in_current_directory %}
        <h2>Images in Current Directory:</h2>
        <ul>
            {% for name, path in images_in_current_directory %}
                <li>
                    <p>{{ name }}</p>
                    <img src="{{ url_for('image', filename=path) }}" alt="{{ name }}">
                </li>
            {% endfor %}
        </ul>
    {% endif %}

    {% if images_in_subdirectories %}
        <h2>Images in Subdirectories:</h2>
        <ul>
            {% for name, path in images_in_subdirectories %}
                <li>
                    <a href="{{ name }}">{{ name }}</a>
                    <br />
                    <img src="{{ url_for('image', filename=path) }}" alt="{{ name }}">
                </li>
            {% endfor %}
        </ul>
    {% endif %}
</body>
</html>
"""


def sort_num(s):
    m = re.match(r'(\d+)', s)
    return int(m.groups()[0]) if m else -1


def get_images_in_directory(directory):
    images = []
    items = os.listdir(directory)
    items.sort(key=sort_num)
    for filename in items:
        if filename.lower().endswith(('.png', '.jpg', '.jpeg', '.gif', '.bmp')):
            images.append((directory, '/'.join([directory, filename])))
    return images


def get_images_in_subdirectories(directory):
    images = []
    items = os.listdir(directory)
    items.sort()
    for subdirectory in items:
        subdirectory_path = os.path.join(directory, subdirectory)
        if os.path.isdir(subdirectory_path):
            images_in_subdirectory = get_images_in_directory(subdirectory_path)
            if images_in_subdirectory:
                images.append(images_in_subdirectory[0])
    return images


@app.route('/')
@app.route('/<path:directory>')
def index(directory='.'):
    images_in_current_directory = get_images_in_directory(directory)
    images_in_current_directory = [
            (path.split('/')[-1], path)
            for (_, path) in images_in_current_directory
            ]
    images_in_subdirectories = get_images_in_subdirectories(directory)

    return render_template_string(index_template,
                                   current_path=directory,
                                   images_in_current_directory=images_in_current_directory,
                                   images_in_subdirectories=images_in_subdirectories)


@app.route('/image/<path:filename>')
def image(filename):
    return send_from_directory(current_path, filename)


if __name__ == '__main__':
    app.run(host='::0', port=8000, debug=os.getenv('DEBUG') == '1')
