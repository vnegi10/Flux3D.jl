@info "Testing PointCloud..."
@testset "PointCloud" begin
    for T = [Float32,Float64], _N = [true, false]
        points = rand(T,3,16,4)
        _normals = rand(T,3,16,4)
        if _N
            normals = _normals
        else
            normals = nothing
        end
        rep = PointCloud(points, normals)
        if normals == nothing
            @test rep.normals isa Nothing
        else
            @test size(rep.normals) == size(_normals)
            @test rep.normals isa Array{Float32,3}
        end
        @test npoints(rep) == size(points,2)
        @test size(rep.points) == size(points)
        @test rep.points isa Array{Float32,3}

        for i in 1:size(points,3)
            @test all(isapprox.(rep[i], points[:,:,i]))
        end

        # using other contructor
        rep1 = PointCloud(points=points, normals=normals)
        rep2 = PointCloud(rep)
        @test rep.points == rep1.points
        @test rep.points == rep2.points
        @test rep.normals == rep1.normals
        @test rep.normals == rep2.normals
    end
end

@info "Testing Meshes..."
@testset "TriMesh" begin

    verts1 = [0.1 0.3 0.5;
              0.5 0.2 0.1;
              0.6 0.8 0.7]
    verts2 = [0.1 0.3 0.3;
              0.6 0.7 0.8;
              0.2 0.3 0.4;
              0.1 0.5 0.3]
    verts3 = [0.7 0.3 0.6;
              0.2 0.4 0.8;
              0.9 0.5 0.2;
              0.2 0.3 0.4;
              0.9 0.3 0.8]

    verts_list = [verts1, verts2, verts3]

    faces1 = [1 2 3]
    faces2 = [1 2 3;
              2 3 4]
    faces3 = [2 3 1;
              1 2 4;
              3 4 2;
              5 4 3;
              5 1 2;
              5 4 2;
              5 3 2]

    faces_list = [faces1, faces2, faces3]
    m = TriMesh(verts_list, faces_list)

    # IO Tests
    @testset "IO" begin
        mktempdir() do tmpdir
            for ext in ["obj", "off", "stl", "ply", "2dm"]
                save_trimesh(joinpath(tmpdir, "test.$(ext)"), m)
                m_loaded = load_trimesh(joinpath(tmpdir, "test.$(ext)"))
                @test all(isapprox.(get_verts_packed(m_loaded), verts_list[1]))
                @test get_faces_packed(m_loaded) == faces_list[1]
            end
        end
    end

    @test all(verts_list .== get_verts_list(m))
    @test cat(verts_list...; dims=1) == get_verts_packed(m)
    _padded = get_verts_padded(m)
    for (i,v) in enumerate(verts_list)
        @test _padded[1:size(v,1),:,i] == v
        @test all(_padded[size(v,1)+1:end,:,i] .== 0)
    end

    @test all(faces_list .== get_faces_list(m))
    _packed = get_faces_packed(m)
    _cur_idx = 1
    _offset = 0
    for (i,f) in enumerate(faces_list)
        @test _packed[_cur_idx:_cur_idx+size(f,1)-1,:] == (f .+ _offset)
        _cur_idx += size(f,1)
        _offset += size(verts_list[i],1)
    end
    @test cat(verts_list...; dims=1) == get_verts_packed(m)
    _padded = get_faces_padded(m)
    for (i,v) in enumerate(faces_list)
        @test _padded[1:size(v,1),:,i] == v
        @test all(_padded[size(v,1)+1:end,:,i] .== 0)
    end

    get_edges_packed(m)
    _packed = get_faces_packed(m)

    e12 = cat(_packed[:, 1], _packed[:, 2], dims = 2)
    e23 = cat(_packed[:, 2], _packed[:, 3], dims = 2)
    e31 = cat(_packed[:, 3], _packed[:, 1], dims = 2)
    edges = cat(e12, e23, e31, dims = 1)
    edges = sort(edges, dims = 2)
    edges = sortslices(edges; dims=1)
    edges = unique(edges; dims = 1)
    @test edges == get_edges_packed(m)

    _dict = get_edges_to_key(m)
    for i in 1:size(edges,1)
        @test i == _dict[Tuple(edges[i,:])]
    end

    _f_edges = get_faces_to_edges_packed(m)
    _packed = get_faces_packed(m)
    for i in 1:size(_f_edges,1)
        @test edges[_f_edges[i,1],:] == sort(_packed[i,[2,3]])
        @test edges[_f_edges[i,2],:] == sort(_packed[i,[1,3]])
        @test edges[_f_edges[i,3],:] == sort(_packed[i,[1,2]])
    end

    _edges = get_edges_packed(m)
    V = size(get_verts_packed(m), 1)
    L = zeros(V,V)
    deg = zeros(V,V)
    for i in 1:size(_edges, 1)
        L[_edges[i,1], _edges[i,2]] = 1
        L[_edges[i,2], _edges[i,1]] = 1
    end
    deg = sum(L; dims = 2)
    deg = map(x -> (x > 0 ? 1 / x : x), deg)
    for i=1:V, j=1:V
        if i==j
            L[i,j] = -1
        elseif L[i,j]==1
            L[i,j] = deg[i]
        end
    end
    @test all(isapprox.(L, Array(get_laplacian_packed(m)), rtol = 1e-5, atol = 1e-5))

    # verts_normals, faces_normals, faces_areas
    verts1 = [0.1 0.3 0.0;
             0.5 0.2 0.0;
             0.6 0.8 0.0;
             0.0 0.3 0.2;
             0.0 0.2 0.5;
             0.0 0.8 0.7;
             0.5 0.0 0.2;
             0.6 0.0 0.5;
             0.8 0.0 0.7;
             0.0 0.0 0.0;
             0.0 0.0 0.0;
             0.0 0.0 0.0]

    verts2 = [0.1 0.3 0.0;
              0.5 0.2 0.0;
              0.6 0.8 0.0;
              0.0 0.3 0.2;
              0.0 0.2 0.5;
              0.0 0.8 0.7]

    verts2 = [0.1 0.3 0.0;
              0.5 0.2 0.0;
              0.0 0.3 0.2;
              0.0 0.2 0.5;
              0.0 0.8 0.7]


    faces1 = [1 2 3;
             4 5 6;
             7 8 9;
             10 11 12]

    faces2 = [1 2 3;
              3 4 5]


    _normal1 = [0.0 0.0 1.0;
                0.0 0.0 1.0;
                0.0 0.0 1.0;
                -1.0 0.0 0.0;
                -1.0 0.0 0.0;
                -1.0 0.0 0.0;
                0.0 1.0 0.0;
                0.0 1.0 0.0;
                0.0 1.0 0.0;
                0.0 0.0 0.0;
                0.0 0.0 0.0;
                0.0 0.0 0.0]

    _normal2 = [-0.2408 -0.9631 -0.1204;
                -0.2408 -0.9631 -0.1204;
                -0.9389 -0.3414 -0.0427;
                -1.0000 0.0000 0.0000;
                -1.0000 0.0000 0.0000]

    _fnormal1 = [-0.0 0.0 1.0;
                 -1.0 0.0 0.0;
                 0.0 1.0 0.0;
                 0.0 0.0 0.0]

    _fnormal2 = [-0.2408 -0.9631 -0.1204;
                 -1.0000 0.0000 0.0000;]

    _farea1 = [0.125, 0.1, 0.02, 0.0]
    _farea2 = [0.0415, 0.1]

    # verts_normals, faces_normals, faces_areas
    for T in [Float64, Float32], R in [Int64, UInt32]

        verts = [T.(verts1), T.(verts2)]
        faces = [R.(faces1), R.(faces2)]
        m = TriMesh(verts, faces)

        @test compute_verts_normals_packed(m) isa Array{T,2}
        @test compute_verts_normals_padded(m) isa Array{T,3}
        @test compute_verts_normals_list(m) isa Array{AbstractArray{T,2},1}
        @test all(isapprox.(cat(_normal1,_normal2; dims=1), compute_verts_normals_packed(m), rtol = 1e-4, atol = 1e-4))
        @test all(isapprox.([_normal1, _normal2], compute_verts_normals_list(m), rtol = 1e-4, atol = 1e-4))
        @test all(isapprox.(_normal1, compute_verts_normals_padded(m)[1:size(_normal1,1),:,1], rtol = 1e-4, atol = 1e-4))
        @test all(isapprox.(_normal2, compute_verts_normals_padded(m)[1:size(_normal2,1),:,2], rtol = 1e-4, atol = 1e-4))
        @test all(compute_verts_normals_padded(m)[size(_normal1,1)+1:end,:,1] .== 0)
        @test all(compute_verts_normals_padded(m)[size(_normal2,1)+1:end,:,2] .== 0)

        @test compute_faces_normals_packed(m) isa Array{T,2}
        @test compute_faces_normals_padded(m) isa Array{T,3}
        @test compute_faces_normals_list(m) isa Array{AbstractArray{T,2},1}
        @test all(isapprox.(cat(_fnormal1,_fnormal2; dims=1), compute_faces_normals_packed(m), rtol = 1e-4, atol = 1e-4))
        @test all(isapprox.([_fnormal1, _fnormal2], compute_faces_normals_list(m), rtol = 1e-4, atol = 1e-4))
        @test all(isapprox.(_fnormal1, compute_faces_normals_padded(m)[1:size(_fnormal1,1),:,1], rtol = 1e-4, atol = 1e-4))
        @test all(isapprox.(_fnormal2, compute_faces_normals_padded(m)[1:size(_fnormal2,1),:,2], rtol = 1e-4, atol = 1e-4))
        @test all(compute_faces_normals_padded(m)[size(_fnormal1,1)+1:end,:,1] .== 0)
        @test all(compute_faces_normals_padded(m)[size(_fnormal2,1)+1:end,:,2] .== 0)

        @test compute_faces_areas_packed(m) isa Array{T,1}
        @test compute_faces_areas_padded(m) isa Array{T,3}
        @test compute_faces_areas_list(m) isa Array{AbstractArray{T,2},1}
        @test all(isapprox.(cat(_farea1,_farea2; dims=1), compute_faces_areas_packed(m), rtol = 1e-4, atol = 1e-4))
        @test all(isapprox.([_farea1, _farea2], compute_faces_areas_list(m), rtol = 1e-4, atol = 1e-4))
        @test all(isapprox.(_farea1, compute_faces_areas_padded(m)[1:size(_farea1,1),:,1], rtol = 1e-4, atol = 1e-4))
        @test all(isapprox.(_farea2, compute_faces_areas_padded(m)[1:size(_farea2,1),:,2], rtol = 1e-4, atol = 1e-4))
        @test all(compute_faces_areas_padded(m)[size(_farea1,1)+1:end,:,1] .== 0)
        @test all(compute_faces_areas_padded(m)[size(_farea2,1)+1:end,:,2] .== 0)
    end
end

@info "Testing Rep Utils..."
@testset "Rep Utils" begin
    for T in [Float64, Float32, Int64, UInt32]
        a1 = [1 2 3;
              4 5 6;
              7 8 9;
              10 11 12]

        a2 = [13 14 15;
              16 17 18]

        a3 = [19 20 21;
              22 23 24;
              25 26 27]

        _list = [T.(a1),T.(a2),T.(a3)]

        _packed = [1 2 3;
                   4 5 6;
                   7 8 9;
                   10 11 12;
                   13 14 15;
                   16 17 18;
                   19 20 21;
                   22 23 24;
                   25 26 27]
        _packed = T.(_packed)

        _padded = zeros(4, 3, 3)
        _padded[1:size(a1,1),:,1] = a1
        _padded[1:size(a2,1),:,2] = a2
        _padded[1:size(a3,1),:,3] = a3
        _padded = T.(_padded)

        items_len, packed_first_idx, packed_to_list_idx =
            Flux3D._auxiliary_mesh(_list)

        @test items_len == [4,2,3]
        @test packed_first_idx == [1,5,7]
        @test all(packed_to_list_idx[1:4] .== 1)
        @test all(packed_to_list_idx[5:6] .== 2)
        @test all(packed_to_list_idx[7:9] .== 3)

        @test Flux3D._list_to_padded(_list, 0) == _padded
        @test Flux3D._list_to_padded(_list, 0) isa Array{T,3}
        @test gradient(x-> 0.5 .* sum(Flux3D._list_to_padded(x, 0) .^ 2), _list)[1] == _list

        @test Flux3D._list_to_packed(_list) == _packed
        @test Flux3D._list_to_packed(_list) isa Array{T,2}
        @test gradient(x->.5 .* sum(Flux3D._list_to_packed(x) .^ 2), _list)[1] == Tuple(_list)

        @test Flux3D._packed_to_padded(_packed, items_len, 0) == _padded
        @test Flux3D._packed_to_padded(_packed, items_len, 0) isa Array{T,3}
        @test gradient(x-> .5 .* sum(Flux3D._packed_to_padded(x, items_len, 0) .^ 2), _packed)[1] == _packed

        @test Flux3D._packed_to_list(_packed, items_len) == _list
        @test Flux3D._packed_to_list(_packed, items_len) isa Array{<:AbstractArray{T,2},1}
        gs = gradient(_packed) do x
                loss = 0
                for x in Flux3D._packed_to_list(x, items_len)
                    loss += sum(x .^ 2)
                end
                return 0.5*loss
            end
        @test gs[1] == _packed

        @test Flux3D._padded_to_list(_padded, items_len) == _list
        @test Flux3D._padded_to_list(_padded, items_len) isa Array{<:AbstractArray{T,2},1}
        gs = gradient(_padded) do x
                loss = 0
                for x in Flux3D._padded_to_list(x, items_len)
                    loss += sum(x .^ 2)
                end
                return 0.5*loss
            end
        @test gs[1] == _padded

        @test Flux3D._padded_to_packed(_padded, items_len) == _packed
        @test Flux3D._padded_to_packed(_padded, items_len) isa Array{T,2}
        @test gradient(x->sum(.5 .* sum(Flux3D._padded_to_packed(x, items_len) .^2 )), _padded)[1] == _padded
    end
end
