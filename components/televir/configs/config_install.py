class TelevirLayout:
    # databases. chose at least one.
    install_refseq_prot = True
    install_refseq_gen = True
    install_swissprot = False
    install_rvdb = False
    install_virosaurus = True
    install_request_sequences = False
    install_ribo16s = False
    install_refseq_16s = False
    
    # hosts ### CHECK HOST LIBRARY FILE FOR AVAILABLE HOSTS ###
    HOSTS_TO_INSTALL = [
        "hg38",
    ]

    # host mappers
    install_bowtie2_remap = True
    install_bowtie2_depletion = False
    install_bwa_host = True
    install_bwa_filter= True

    # classification software.
    install_metaphlan = False
    install_voyager_viral = False
    install_centrifuge = True
    install_centrifuge_bacteria = False
    install_kraken2 = True
    install_kraken2_bacteria = False
    install_kraken2_eupathdb46 = False
    install_krakenuniq = True
    install_krakenuniq_fungi = False
    install_kaiju = True
    install_diamond = True
    install_minimap2 = True
    install_fastviromeexplorer = False
    install_blast = True

    # assemblers.
    install_spades = True
    install_raven = True
    install_flye = True

    # technology setup (exclusive technologies. overrides info above).
    install_illumina = True
    install_nanopore = True

    # check files
    check_index_files = False
