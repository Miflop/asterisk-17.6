FROM centos:latest
ENV build_date 15/08/2020
ARG Host
ARG IP
ARG Domain

RUN rm -f /etc/localtime
RUN ln -s /usr/share/zoneinfo/Europe/Madrid /etc/localtime

WORKDIR /etc
RUN echo $Host >> hostname
WORKDIR /etc
RUN echo $IP $Domain >> hosts

RUN dnf --enablerepo=PowerTools install libsrtp-devel gsm-devel speex-devel libedit libedit-devel diffutils wget -y

RUN yum update -y && \
#    yum update mysql-community-release -y && \
    yum install -y epel-release && \
    yum install \
        git \
        kernel-headers \
        gcc \
        gcc-c++ \
        cpp \
        ncurses \
        ncurses-devel \
        libxml2 \
        libxml2-devel \
        sqlite \
        sqlite-devel \
        openssl-devel \
        newt-devel \
        kernel-devel \
        libuuid-devel \
        net-snmp-devel \
        xinetd \
        tar \
        jansson-devel \
        make \
        bzip2 \
        pjproject-devel \
        libsrtp-devel \
        gsm-devel \
        speex-devel \
        gettext \
        unixODBC \
        unixODBC-devel \
        libtool-ltdl \
        libtool-ltdl-devel \
        mariadb-connector-odbc \
        -y

WORKDIR /usr/src
RUN git clone -b 17.6.0 --depth 1 https://github.com/asterisk/asterisk.git

WORKDIR /usr/src/asterisk
# Configure
RUN sh contrib/scripts/install_prereq install
RUN sh contrib/scripts/get_mp3_source.sh
RUN ./configure --libdir=/usr/lib64 1> /dev/null
# Remove the native build option
# from: https://wiki.asterisk.org/wiki/display/AST/Building+and+Installing+Asterisk
RUN make menuselect.makeopts
RUN menuselect/menuselect \
  --disable BUILD_NATIVE \
  --enable format_mp3 \
  --enable cdr_csv \
  --disable chan_sip \
  --enable res_snmp \
  --enable res_http_websocket \
  --enable res_hep_pjsip \
  --enable res_hep_rtcp \
  --enable res_sorcery_astdb \
  --enable res_sorcery_config \
  --enable res_sorcery_memory \
  --enable res_sorcery_memory_cache \
  --enable res_pjproject \
  --enable res_rtp_asterisk \
  --enable res_ari \
  --enable res_ari_applications \
  --enable res_ari_asterisk \
  --enable res_ari_bridges \
  --enable res_ari_channels \
  --enable res_ari_device_states \
  --enable res_ari_endpoints \
  --enable res_ari_events \
  --enable res_ari_mailboxes \
  --enable res_ari_model \
  --enable res_ari_playbacks \
  --enable res_ari_recordings \
  --enable res_ari_sounds \
  --enable res_pjsip \
  --enable res_pjsip_acl \
  --enable res_pjsip_authenticator_digest \
  --enable res_pjsip_caller_id \
  --enable res_pjsip_config_wizard \
  --enable res_pjsip_dialog_info_body_generator \
  --enable res_pjsip_diversion \
  --enable res_pjsip_dlg_options \
  --enable res_pjsip_dtmf_info \
  --enable res_pjsip_empty_info \
  --enable res_pjsip_endpoint_identifier_anonymous \
  --enable res_pjsip_endpoint_identifier_ip \
  --enable res_pjsip_endpoint_identifier_user \
  --enable res_pjsip_exten_state \
  --enable res_pjsip_header_funcs \
  --enable res_pjsip_logger \
  --enable res_pjsip_messaging \
  --enable res_pjsip_mwi \
  --enable res_pjsip_mwi_body_generator \
  --enable res_pjsip_nat \
  --enable res_pjsip_notify \
  --enable res_pjsip_one_touch_record_info \
  --enable res_pjsip_outbound_authenticator_digest \
  --enable res_pjsip_outbound_publish \
  --enable res_pjsip_outbound_registration \
  --enable res_pjsip_path \
  --enable res_pjsip_pidf_body_generator \
  --enable res_pjsip_publish_asterisk \
  --enable res_pjsip_pubsub \
  --enable res_pjsip_refer \
  --enable res_pjsip_registrar \
#  --enable res_pjsip_registrar_expire \
  --enable res_pjsip_rfc3326 \
  --enable res_pjsip_sdp_rtp \
  --enable res_pjsip_send_to_voicemail \
  --enable res_pjsip_session \
  --enable res_pjsip_sips_contact \
  --enable res_pjsip_t38 \
  --enable res_pjsip_transport_websocket \
  --enable res_pjsip_xpidf_body_generator \
  --enable res_stasis \
  --enable res_stasis_answer \
  --enable res_stasis_device_state \
  --enable res_stasis_mailbox \
  --enable res_stasis_playback \
  --enable res_stasis_recording \
  --enable res_stasis_snoop \
  --enable res_stasis_test \
  --enable res_statsd \
  --enable res_timing_timerfd \
  menuselect.makeopts

# ./buildmenu.sh app_stasis res_stasis cdr_syslog chan_bridge_media chan_rtp chan_pjsip codec_a_mu codec_ulaw pbx_config

# Continue with a standard make.
RUN make 1> /dev/null
RUN make install 1> /dev/null
RUN make samples 1> /dev/null
WORKDIR /

# Update max number of open files.
RUN sed -i -e 's/# MAXFILES=/MAXFILES=/' /usr/sbin/safe_asterisk

# Copy in default configs
COPY http.conf /etc/asterisk/http.conf
COPY extconfig.conf /etc/asterisk/extconfig.conf
COPY asterisk.conf /etc/asterisk/asterisk.conf
COPY res_config_mysql.conf /etc/asterisk/res_config_mysql.conf
COPY odbc.ini /etc/odbc.ini
COPY res_odbc.conf /etc/asterisk/res_odbc.conf
COPY cdr_adaptive_odbc.conf /etc/asterisk/cdr_adaptive_odbc.conf
COPY ari.conf /etc/asterisk/ari.conf
COPY logger.conf /etc/asterisk/logger.conf
COPY manager.conf /etc/asterisk/manager.conf
COPY odbcinst.ini /etc/odbcinst.ini

# This is weird huh? I'd shell into the container and get errors about en_US.UTF-8 file not found
# found @ https://github.com/CentOS/sig-cloud-instance-images/issues/71
#RUN localedef -i en_US -f UTF-8 en_US.UTF-8

VOLUME /var/lib/asterisk
VOLUME /etc/asterisk
VOLUME /var/spool/asterisk

EXPOSE 5060
EXPOSE 10000-20000/UDP
# And run asterisk in the foreground.
CMD asterisk -f
