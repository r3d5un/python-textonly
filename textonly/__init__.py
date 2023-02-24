import logging

from flask import Flask


def create_app():
    app = Flask(__name__)

    app.logger.setLevel(logging.DEBUG)

    @app.route("/")
    def hello_world():  # put application's code here
        return "Hello World!"

    return app
