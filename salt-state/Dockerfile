FROM python:3.6-slim

WORKDIR /root/

RUN rm /bin/sh && ln -s /bin/bash /bin/sh

RUN apt update &&\
	 apt-get install -y sudo vim build-essential libssl-dev libffi-dev python-dev libpcap-dev supervisor
RUN pip install opencanary

ADD supervise-opencanary.conf /etc/supervisor/conf.d/supervise-opencanary.conf

ADD startcanary.sh /opt/opencanary/scripts/startcanary.sh
RUN chmod +x /opt/opencanary/scripts/startcanary.sh

CMD ["/usr/bin/supervisord", "-n"]