FROM cycloid/cycloid-toolkit:latest

COPY cy-provisioner cy-initializer.py /bin
RUN chmod 555 /bin/cy-provisioner
RUN chmod 555 /bin/cy-initializer.py

CMD /bin/cy-provisioner
