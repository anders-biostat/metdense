@enum MethCall ::UInt32 begin
    nocall = 0x00
    unmeth = 0x01
    meth = 0x02
    ambig = 0x03
end

struct GenomicPosition
    chrom :: String
    pos :: UInt32
end

struct GenomicInterval
    chrom :: String
    iv :: Range{UInt32}
end

struct MetDenseFile
    f ::IOStream
    cell_names ::Vector{String}
    chroms_dict ::Dict{ String, StepRange{UInt64} }
    offset_data_block ::UInt64
end

function MetDenseFile( filename ::String )
    f = open( filename )

    # Read and check magic string
    s = Vector{UInt8}(undef,8)
    readbytes!( f, s )
    @assert s == Vector{UInt8}("MetDense")

    # Read version
    version = ( read( f, UInt32 ), read( f, UInt32 ) )
    @assert version == ( 0, 1 )

    # Get offsets
    offset_data_block = read( f, UInt64 )
    offset_chroms_block = read( f, UInt64 )

    # Read Cells block
    n_cells = read( f, UInt32 )
    names_cells = [ readline( f ) for i in 1:n_cells ]

    # Read Chromosomes block
    seek( f, offset_chroms_block )
    n_chroms = read( f, UInt32 )
    offsets_chroms = [ read( f, UInt64 ) for i in 1:n_chroms ]
    names_chroms = [ readline( f ) for i in 1:n_chroms ]

    chroms_dict = Dict( names_chroms[i] =>
        range( offsets_chroms[i],
            i < n_chroms ? offsets_chroms[i + 1] - 1 : offset_chroms_block - 1;
            step = 4 * ceil(UInt64, n_cells / 16))
        for i = 1:n_chroms )

    MetDenseFile( f, names_cells, chroms_dict, offset_data_block )
end

function read_at_position( f, pos, type )
    seek( f, pos )
    read( f, type )
end

function get_position( mdf ::MetDenseFile, gi:: GenomicInterval )
    from = searchsortedfirst(
        mdf.chroms_dict[ gp.chrom ], gp.pos,
        by = ( x -> read_at_position( mdf.f, x, UInt32 ) ) )
     to = searchsortedlast(
        mdf.chroms_dict[ gp.chrom ], gp.pos,
        by = ( x -> read_at_position( mdf.f, x, UInt32 ) ) )
    range( from, to )
end

function main()

    mdf = MetDenseFile( "test.metdense" )

    print( get_position( mdf, GenomicPosition( "2", 1234567 ) ) )

end


main()

gp = GenomicPosition( "2", 1234567 )

df = MetDenseFile("data/test.metdense")
df.chroms_dict
