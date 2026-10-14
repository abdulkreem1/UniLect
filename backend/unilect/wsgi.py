import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "unilect.settings.prod")
application = get_wsgi_application()
