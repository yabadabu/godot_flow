#include "platform.h"
#include "modules/module.h"
#include "render/render.h"
#include "render/color.h"

// From https://github.com/nushoin/RTree/issues/15
#include "rtree.h"

// https://github.com/virtuald/r-star-tree
// https://github.com/tidwall/rtree.c
// https://github.com/mourner/flatbush

// ---------------------------------------------------------------
struct TModuleRTree : public TModule {

  struct TStoredData {
    VEC4     color;
    TAABB    aabb;
  };

  using RTree2Df = RTree<int, float, 2>;

  const char* getName() const override { return "rtree"; }
  bool hasConfig() const override { return false; }
  virtual bool startsEnabled() const { return false; }
  
  // ---------------------------------------------------------------
  RTree2Df                 tree;
  std::vector<TStoredData> all_instances;
  Render::VInstances       render_instances;
  Render::VInstances       all_render_instances;

  int seed = 123213;
  int ninstances = 500;
  float xz_range = 10.0f;
  float size_range = 0.4f;

  TTransform ref_point;
  float      ref_radius = 2.0f;

  int nhits = 0;
  double time_searching = 0.0f;

  MAT44 asWorld(const TAABB& aabb) {
    return MAT44::CreateScale(aabb.half * 2.f) * MAT44::CreateTranslation(aabb.center);
  }

  // ---------------------------------------------------------------
  void initialize() {
    TRandomSequence rseq(seed);

    tree.RemoveAll();
    
    all_render_instances.clear();
    all_render_instances.reserve(ninstances);

    all_instances.resize(ninstances);
    uint32_t id = 0;
    for( auto& instance : all_instances) {

      // Create instance
      instance.color = rseq.between(Color::Red, Color::Blue);
      instance.color.y = 1.0f;

      TAABB& aabb = instance.aabb;
      aabb.half = rseq.between(VEC3::ones * 0.1f, VEC3::ones) * size_range;
      aabb.center = rseq.between(VEC3(-xz_range, 0.0f, -xz_range), VEC3(xz_range, 0, xz_range));
      aabb.center.y += aabb.half.y;

      // Register in the tree by id
      float vmin[2] = { aabb.center.x - aabb.half.x, aabb.center.z - aabb.half.z };
      float vmax[2] = { aabb.center.x + aabb.half.x, aabb.center.z + aabb.half.z };
      tree.Insert(vmin, vmax, id);

      all_render_instances.emplace_back(asWorld(aabb), Color::White * 0.2f);

      // Next id
      ++id;
    }

    nhits = 0;
    render_instances.clear();
    sendQuery();
  }

  // ---------------------------------------------------------------
  void load(const json& jcfg) override {
    subscribe(this, &TModuleRTree::renderDebug3D);
    initialize();
  }

  void renderDebug3D(MsgAppRenderDebug3D& msg) {
    const Render::TMesh* mesh = Resources.get("unit_wired_cube.mesh")->as<Render::TMesh>();
    Render::drawInstancedPrimitives(mesh, render_instances.data(), (uint32_t)render_instances.size());
    Render::drawInstancedPrimitives(mesh, all_render_instances.data(), (uint32_t)all_render_instances.size());
    Render::drawAABB(TAABB(ref_point.getPosition(), VEC3::ones * ref_radius), MAT44::Identity, Color::White);
  }

  void sendQuery() {
    TTimer tm;
    VEC3 center = ref_point.position;
    float vmin[2] = { center.x - ref_radius, center.z - ref_radius };
    float vmax[2] = { center.x + ref_radius, center.z + ref_radius };
    render_instances.clear();
    nhits = tree.Search(vmin, vmax, [this](const int& id) -> bool{
      const TStoredData& s = all_instances[id];
      render_instances.emplace_back(asWorld(s.aabb), s.color);
      return true;
      });
    time_searching = tm.elapsed();
  }

  void renderInMenu() override {
    bool requery = false;
    requery |= renderObjInMenu(ref_point, "Ref");
    requery |= ImGui::DragFloat("Radius", &ref_radius, 0.01f, 0.0f, 10.0f);
    bool regenerate = false;
    regenerate |= ImGui::DragInt("Num Instances", &ninstances, 1.0f, 0, 1000);
    regenerate |= ImGui::DragFloat("Gen Range", &xz_range, 0.01f, 0.0f, 20.0f);
    regenerate |= ImGui::DragFloat("Size Range", &size_range, 0.01f, 0.0f, 5.0f);
    ImGui::Text("%d hits", nhits);
    ImGui::Text("%lf secs", time_searching);
    if (regenerate)
      initialize();
    if (requery)
      sendQuery();
  }

  void update() {

  }
};

TModuleRTree module_rtree;
