ARG APP_NAME=textonly
ARG APP_PATH=/opt/$APP_NAME
ARG PYTHON_VERSION=3.11.1
ARG POETRY_VERSION=1.3.2

# STAGING STAGE
FROM python:$PYTHON_VERSION as staging

ARG APP_NAME
ARG APP_PATH
ARG POETRY_VERSION

ENV \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1
ENV \
    POETRY_VERSION=$POETRY_VERSION \
    POETRY_HOME="/opt/poetry" \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_NO_INTERACTION=1

# 1. STAGE THE PROJECT
# Installs Poetry and copies project files
RUN curl -sSL https://install.python-poetry.org | python
ENV PATH="$POETRY_HOME/bin:$PATH"

# Copy project files
WORKDIR $APP_PATH
COPY ./poetry.lock ./pyproject.toml ./
COPY ./$APP_NAME ./$APP_NAME

# DEVELOPMENT MODE
FROM staging as development
ARG APP_NAME
ARG APP_PATH

WORKDIR $APP_PATH
RUN poetry install

# Use Flask development server when in development mode
ENV FLASK_APP=$APP_NAME \
    FLASK_ENV=development \
    FLASK_RUN_HOST=0.0.0.0 \
    FLASK_RUN_PORT=8888

ENTRYPOINT ["poetry", "run"]
CMD ["flask", "run"]

# BUILD STAGE
# Installs dependencies and builds the project into a wheel file
FROM staging as build
ARG APP_PATH

WORKDIR $APP_PATH
RUN poetry build --format wheel
RUN poetry export --format requirements.txt --output constraints.txt --without-hashes

# PRODUCTION MODE
# Production image will start from a clean Python image, then install the wheel file.
FROM python:$PYTHON_VERSION-alpine as production

# Redefining variables to make them available in this image
ARG APP_NAME
ARG APP_PATH

ENV \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1

ENV \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100

# Installing the wheel build from the BUILD STAGE
WORKDIR $APP_PATH
COPY --from=build $APP_PATH/dist/*.whl ./
COPY --from=build $APP_PATH/constraints.txt ./
RUN pip install ./$APP_NAME*.whl --constraint constraints.txt

# Use Gunicorn as the production server
ENV PORT=8888
ENV APP_NAME=$APP_NAME

CMD gunicorn --bind :$PORT --workers 4 --threads 4 --timeout 0 "$APP_NAME:create_app()"
