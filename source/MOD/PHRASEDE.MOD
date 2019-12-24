IMPLEMENTATION MODULE PhraseDefs;

(* Phrase Defs  - Phrase file definitions.

    The phrase file is the file Time Line uses to read text for customer
    interactions, other than help and forms.  It is on disk to save memory
    room and be internationalized.

    The phrase file is "compiled" by MSGCOMP from an ascii-text file into
    an internal format.  The internal format is designed for quick access,
    not disk space savings.  No compression of the data is performed.

    The phrase file's source text file name is usually TLPHRASE.TXT.
    The phrase file's "compiled" text is called TLPHRAS4.DAT.


    This def is designed to be used by both Time Line and by MSGCOMP, the
    phrase file compiler.

    The phrase file's internals were redesigned for LAZLO (DOS V4) by Roger
    Collins, and the NEW design is reflected in this module.

    Phrases are accessed by both a message CLASS and a message NUMBER.
    In the source text file, classes are designated by name.  Internally,
    classes are designated by number only, for ease of internationalization.
    The number of classes is dynamic, so that products added in the field
    can receive new classes of messages for simplicity.

    Notes about the compiled phrase file format:

        The file consists of

            - A file header, including a master index for each message class.
            - The list of "locked" messages.
            - The message blocks.  Each block contains an index to the
              messages in that block.

        Every block contains a block header.

        Messages are stored in order by message CLASS and phrase number.

        The file is accessed as a RELATIVE FILE with blocks of BlockSize.
        This allows a simple (and fast) access method.

    MODIFICATION HISTORY:

    10-Jun-89 RSC First cut of this module.  For the "new" file format.


*)

END PhraseDefs.

