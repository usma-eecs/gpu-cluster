#Dockerfile that changes the customizations in the Data Science Playground's 
# CUDA-enabled image. On Docker Hub as cdasdsp/k8s-notebook:1 (as of 2 Apr)
FROM cdasdsp/dsp-notebook:latest

USER ROOT

RUN usermod -l $NB_USER jovyan

RUN usermod -d /home/jovyan jovyan

#Be a good GPU neighbor
ENV TF_FORCE_GPU_ALLOW_GROWTH=TRUE

USER jovyan

RUN rm $HOME/CAUTION.txt

WORKDIR $HOME

EXPOSE 8888

# Configure container startup
ENTRYPOINT ["tini", "-g", "--"]
CMD ["start-notebook.sh"]